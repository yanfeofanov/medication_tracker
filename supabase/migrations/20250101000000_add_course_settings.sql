-- 20250101000000_add_course_settings.sql
-- Migration: Добавление настроек курса лечения

-- Создание таблицы для курсов лечения
CREATE TABLE IF NOT EXISTS medication_courses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  medication_id UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  duration_type TEXT NOT NULL CHECK (duration_type IN ('week', 'twoWeeks', 'month', 'threeMonths', 'sixMonths', 'year', 'custom', 'lifetime')),
  custom_end_date TIMESTAMP WITH TIME ZONE,
  pills_per_day INTEGER DEFAULT 1,
  total_pills INTEGER DEFAULT 0,
  has_notifications BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, medication_id)
);

-- Добавляем поля в таблицу medications
ALTER TABLE medications 
ADD COLUMN IF NOT EXISTS default_duration_type TEXT,
ADD COLUMN IF NOT EXISTS default_pills_per_day INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS default_total_pills INTEGER,
ADD COLUMN IF NOT EXISTS default_has_notifications BOOLEAN DEFAULT TRUE;

-- Создаем индекс для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_medication_courses_user_medication 
ON medication_courses(user_id, medication_id);

-- Создаем политики безопасности
ALTER TABLE medication_courses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own medication courses"
ON medication_courses FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own medication courses"
ON medication_courses FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own medication courses"
ON medication_courses FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own medication courses"
ON medication_courses FOR DELETE
USING (auth.uid() = user_id);