-- ============================================
-- FIX: Update activities_type_check constraint
-- ============================================
-- Run this in Supabase SQL Editor to fix the constraint
-- The deployed database might have an old constraint that doesn't include 'walk'

-- Step 1: Drop the existing constraint
ALTER TABLE public.activities DROP CONSTRAINT IF EXISTS activities_type_check;

-- Step 2: Add the updated constraint with all activity types
ALTER TABLE public.activities ADD CONSTRAINT activities_type_check 
  CHECK (type IN ('run', 'walk', 'bike', 'hike'));

-- Verify the constraint was added:
-- SELECT conname, pg_get_constraintdef(oid) 
-- FROM pg_constraint 
-- WHERE conrelid = 'public.activities'::regclass;
