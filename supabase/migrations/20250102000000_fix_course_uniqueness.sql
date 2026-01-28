-- Удаляем старую таблицу и создаем заново с правильными ограничениями
DROP TABLE IF EXISTS medication_courses CASCADE;

-- Создаем таблицу для курсов лечения
CREATE TABLE medication_courses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  medication_id UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  duration_type TEXT NOT NULL CHECK (duration_type IN ('week', 'twoWeeks', 'month', 'threeMonths', 'sixMonths', 'year', 'custom', 'lifetime')),
  custom_end_date TIMESTAMP WITH TIME ZONE,
  pills_per_day INTEGER DEFAULT 1,
  total_pills INTEGER DEFAULT 0,
  has_notifications BOOLEAN DEFAULT TRUE,
  injection_frequency TEXT CHECK (injection_frequency IN ('daily', 'weekly', 'biweekly', 'monthly', 'custom')),
  injection_interval_days INTEGER DEFAULT 14,
  injection_days_of_week TEXT,
  injection_notify_day_before BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, medication_id)
);

-- Создаем индекс для быстрого поиска
CREATE INDEX idx_medication_courses_user_medication 
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