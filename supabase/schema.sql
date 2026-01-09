-- ============================================
-- TRAILZAP - SUPABASE DATABASE SCHEMA
-- Complete SQL setup for fitness tracking app
-- ============================================
-- Run this in Supabase SQL Editor (supabase.com/dashboard)
-- Execute in order: Tables → Functions → Triggers → RLS Policies
-- ============================================

-- ============================================
-- PART 1: TABLES
-- ============================================

-- Drop existing tables if needed (uncomment for fresh start)
-- DROP TABLE IF EXISTS activity_points CASCADE;
-- DROP TABLE IF EXISTS activities CASCADE;
-- DROP TABLE IF EXISTS profiles CASCADE;

-- 1. PROFILES TABLE (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  preferred_units TEXT DEFAULT 'metric' CHECK (preferred_units IN ('metric', 'imperial')),
  weekly_goal_km DECIMAL DEFAULT 20.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE public.profiles IS 'User profiles extending Supabase auth.users';

-- 2. ACTIVITIES TABLE (runs, bike rides, hikes)
CREATE TABLE IF NOT EXISTS public.activities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Basic info
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('run', 'walk', 'bike', 'hike')),
  description TEXT,
  
  -- Metrics
  distance_km DECIMAL NOT NULL DEFAULT 0,
  duration_secs INTEGER NOT NULL DEFAULT 0,
  pace_min_per_km DECIMAL, -- Calculated: (duration_secs/60) / distance_km
  calories_burned INTEGER,
  
  -- Time tracking
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE,
  
  -- GPS data (encoded polyline for efficient storage)
  map_polyline TEXT, -- Google Polyline encoded format
  start_lat DECIMAL,
  start_lng DECIMAL,
  end_lat DECIMAL,
  end_lng DECIMAL,
  
  -- Elevation
  elevation_gain DECIMAL DEFAULT 0,
  elevation_loss DECIMAL DEFAULT 0,
  max_elevation DECIMAL,
  min_elevation DECIMAL,
  
  -- Heart rate (optional - from wearables)
  avg_hr INTEGER,
  max_hr INTEGER,
  
  -- Weather (optional - from API)
  weather_temp DECIMAL,
  weather_condition TEXT,
  
  -- Status
  is_public BOOLEAN DEFAULT false,
  is_manual_entry BOOLEAN DEFAULT false, -- If entered manually vs GPS tracked
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_activities_user_id ON public.activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_type ON public.activities(type);
CREATE INDEX IF NOT EXISTS idx_activities_start_time ON public.activities(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_activities_created_at ON public.activities(created_at DESC);

COMMENT ON TABLE public.activities IS 'User fitness activities (runs, bike rides, hikes)';

-- 3. ACTIVITY_POINTS TABLE (detailed GPS waypoints - optional, for detailed analysis)
CREATE TABLE IF NOT EXISTS public.activity_points (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  activity_id UUID REFERENCES public.activities(id) ON DELETE CASCADE NOT NULL,
  
  -- GPS data
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  elevation DECIMAL,
  
  -- Metrics at this point
  distance_from_start DECIMAL, -- cumulative distance in km
  speed_kmh DECIMAL,
  heart_rate INTEGER,
  
  -- Timestamp
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
  
  -- Ordering
  sequence_order INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activity_points_activity_id ON public.activity_points(activity_id);

COMMENT ON TABLE public.activity_points IS 'Detailed GPS waypoints for activities (optional, for detailed route analysis)';


-- ============================================
-- PART 2: FUNCTIONS
-- ============================================

-- Function: Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'username', 'user_' || LEFT(NEW.id::text, 8)),
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    NEW.raw_user_meta_data ->> 'avatar_url'
  );
  RETURN NEW;
END;
$$;

-- Function: Auto-calculate pace when activity is inserted/updated
CREATE OR REPLACE FUNCTION public.calculate_activity_pace()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Calculate pace (minutes per km) only if we have valid distance
  IF NEW.distance_km > 0 AND NEW.duration_secs > 0 THEN
    NEW.pace_min_per_km := (NEW.duration_secs::decimal / 60) / NEW.distance_km;
  ELSE
    NEW.pace_min_per_km := NULL;
  END IF;
  
  -- Update timestamp
  NEW.updated_at := NOW();
  
  RETURN NEW;
END;
$$;

-- Function: Update profile timestamp
CREATE OR REPLACE FUNCTION public.update_profile_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;


-- ============================================
-- PART 3: TRIGGERS
-- ============================================

-- Trigger: Create profile when user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Trigger: Calculate pace on activity insert/update
DROP TRIGGER IF EXISTS on_activity_calculate_pace ON public.activities;
CREATE TRIGGER on_activity_calculate_pace
  BEFORE INSERT OR UPDATE ON public.activities
  FOR EACH ROW
  EXECUTE FUNCTION public.calculate_activity_pace();

-- Trigger: Update profile timestamp
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_profile_timestamp();


-- ============================================
-- PART 4: ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_points ENABLE ROW LEVEL SECURITY;

-- ----- PROFILES POLICIES -----

-- SELECT: Users can view their own profile
CREATE POLICY "profiles_select_own"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- INSERT: Handled by trigger, but allow for edge cases
CREATE POLICY "profiles_insert_own"
  ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- UPDATE: Users can update their own profile
CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- DELETE: Users cannot delete profiles (handled by auth cascade)
-- No delete policy needed

-- ----- ACTIVITIES POLICIES -----

-- SELECT: Users can view their own activities
CREATE POLICY "activities_select_own"
  ON public.activities
  FOR SELECT
  USING (auth.uid() = user_id);

-- SELECT: Users can view public activities (for social features)
CREATE POLICY "activities_select_public"
  ON public.activities
  FOR SELECT
  USING (is_public = true);

-- INSERT: Users can create activities for themselves
CREATE POLICY "activities_insert_own"
  ON public.activities
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can update their own activities
CREATE POLICY "activities_update_own"
  ON public.activities
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can delete their own activities
CREATE POLICY "activities_delete_own"
  ON public.activities
  FOR DELETE
  USING (auth.uid() = user_id);

-- ----- ACTIVITY_POINTS POLICIES -----

-- Users can manage points for their own activities
CREATE POLICY "activity_points_select_own"
  ON public.activity_points
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.activities 
      WHERE activities.id = activity_points.activity_id 
      AND activities.user_id = auth.uid()
    )
  );

CREATE POLICY "activity_points_insert_own"
  ON public.activity_points
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.activities 
      WHERE activities.id = activity_points.activity_id 
      AND activities.user_id = auth.uid()
    )
  );

CREATE POLICY "activity_points_delete_own"
  ON public.activity_points
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.activities 
      WHERE activities.id = activity_points.activity_id 
      AND activities.user_id = auth.uid()
    )
  );


-- ============================================
-- PART 5: REALTIME (Enable for live updates)
-- ============================================

-- Enable realtime for activities table (for live feed updates)
ALTER PUBLICATION supabase_realtime ADD TABLE public.activities;

-- Note: You can also enable from Supabase Dashboard:
-- Database → Replication → Select 'activities' table


-- ============================================
-- PART 6: STORAGE BUCKETS (for avatars)
-- ============================================

-- Run these in Dashboard or via Management API:
-- 1. Create bucket: 'avatars' (public)
-- 2. Create bucket: 'activity-photos' (private)

-- Storage policies (run in SQL Editor):
-- Note: These require the storage schema access

-- Allow users to upload their own avatar
-- INSERT INTO storage.policies (bucket_id, name, definition)
-- VALUES ('avatars', 'Avatar upload policy', ...)


-- ============================================
-- PART 7: HELPFUL VIEWS (optional)
-- ============================================

-- View: User stats summary
CREATE OR REPLACE VIEW public.user_stats AS
SELECT 
  p.id AS user_id,
  p.username,
  COUNT(a.id) AS total_activities,
  COALESCE(SUM(a.distance_km), 0) AS total_distance_km,
  COALESCE(SUM(a.duration_secs), 0) AS total_duration_secs,
  COALESCE(SUM(a.elevation_gain), 0) AS total_elevation_gain,
  COUNT(CASE WHEN a.type = 'run' THEN 1 END) AS total_runs,
  COUNT(CASE WHEN a.type = 'walk' THEN 1 END) AS total_walks,
  COUNT(CASE WHEN a.type = 'bike' THEN 1 END) AS total_rides,
  COUNT(CASE WHEN a.type = 'hike' THEN 1 END) AS total_hikes
FROM public.profiles p
LEFT JOIN public.activities a ON p.id = a.user_id
GROUP BY p.id, p.username;

-- View: Weekly summary for current user
CREATE OR REPLACE VIEW public.weekly_summary AS
SELECT 
  user_id,
  DATE_TRUNC('week', start_time) AS week_start,
  type,
  COUNT(*) AS activity_count,
  SUM(distance_km) AS total_distance,
  SUM(duration_secs) AS total_duration,
  AVG(pace_min_per_km) AS avg_pace
FROM public.activities
WHERE start_time >= NOW() - INTERVAL '4 weeks'
GROUP BY user_id, DATE_TRUNC('week', start_time), type
ORDER BY week_start DESC, type;


-- ============================================
-- VERIFICATION QUERIES (run to test)
-- ============================================

-- Check tables exist
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Check RLS is enabled
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';

-- Check policies
-- SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';

-- Check triggers
-- SELECT trigger_name, event_object_table FROM information_schema.triggers;


-- ============================================
-- SUCCESS! Your TrailZap database is ready.
-- ============================================
