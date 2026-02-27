-- AntiGravity Platform Database Schema

-- 1. Enable pgcrypto for UUID generation (usually enabled by default in Supabase)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. ENUM Types
CREATE TYPE user_role AS ENUM ('candidate', 'recruiter', 'admin');

-- 3. Users Table (Extends Supabase Auth users)
-- This table automatically links to auth.users if you setup a trigger, or we can just manage it manually
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'candidate',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Candidate Profiles Table
CREATE TABLE public.candidate_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    headline TEXT,
    bio TEXT,
    education TEXT,
    experience_years NUMERIC(4,2) DEFAULT 0,
    github_url TEXT,
    linkedin_url TEXT,
    portfolio_url TEXT,
    resume_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Recruiter Profiles Table
CREATE TABLE public.recruiter_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    company_name TEXT NOT NULL,
    company_website TEXT,
    position TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Skills Table (Master Dictionary)
CREATE TABLE public.skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    category TEXT, -- e.g., 'Frontend', 'Backend', 'Soft Skill'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Candidate Skills (Mapping table)
CREATE TABLE public.candidate_skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES public.candidate_profiles(user_id) ON DELETE CASCADE,
    skill_id UUID REFERENCES public.skills(id) ON DELETE CASCADE,
    proficiency_level INTEGER CHECK (proficiency_level BETWEEN 1 AND 5), -- 1=Beginner, 5=Expert
    years_experience NUMERIC(4,2),
    UNIQUE(candidate_id, skill_id)
);

-- 8. Projects Table
CREATE TABLE public.projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recruiter_id UUID REFERENCES public.recruiter_profiles(user_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT DEFAULT 'open', -- 'open', 'closed', 'draft'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. Project Requirements Table
CREATE TABLE public.project_requirements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    skill_id UUID REFERENCES public.skills(id) ON DELETE CASCADE,
    importance_weight NUMERIC(3,2) DEFAULT 1.0, -- Used for weighted matching
    minimum_proficiency INTEGER CHECK (minimum_proficiency BETWEEN 1 AND 5),
    UNIQUE(project_id, skill_id)
);

-- 10. Match Scores Table (Connects Candidates to Projects)
CREATE TABLE public.match_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID REFERENCES public.candidate_profiles(user_id) ON DELETE CASCADE,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    overall_score NUMERIC(5,2) NOT NULL, -- 0-100 score
    explainability_json JSONB, -- Stores the breakdown of why this score was given
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(candidate_id, project_id)
);

-- 11. Fairness Metrics
CREATE TABLE public.fairness_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    diversity_index NUMERIC(5,2),
    bias_score NUMERIC(5,2),
    metrics_json JSONB,
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 12. Audit Logs (Admin tracking)
CREATE TABLE public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL, -- e.g., 'match_score', 'weight_adjustment'
    entity_id UUID,
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recruiter_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fairness_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy Setup

-- 1. Users
-- Users can read their own data
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id);
-- Admins can read all users (Assuming we create an RPC or function to check admin status, for now allow read for now but secure updates)
-- Quick helper function to check if user is admin:
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE POLICY "Admins can view all users" ON public.users FOR SELECT USING (public.is_admin());
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- 2. Candidate Profiles
CREATE POLICY "Candidates can view own profile" ON public.candidate_profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Candidates can create own profile" ON public.candidate_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Candidates can update own profile" ON public.candidate_profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Recruiters and Admins can view all candidates" ON public.candidate_profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('recruiter', 'admin'))
);

-- 3. Recruiter Profiles
CREATE POLICY "Anyone can view recruiter profiles" ON public.recruiter_profiles FOR SELECT USING (true);
CREATE POLICY "Recruiters can insert own profile" ON public.recruiter_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Recruiters can update own profile" ON public.recruiter_profiles FOR UPDATE USING (auth.uid() = user_id);

-- 4. Skills
-- Everyone can read skills
CREATE POLICY "Skills are readable by everyone" ON public.skills FOR SELECT USING (true);
-- Only admins can add/update/delete skills
CREATE POLICY "Admins can manage skills" ON public.skills FOR ALL USING (public.is_admin());

-- 5. Candidate Skills
CREATE POLICY "Candidates manage own skills" ON public.candidate_skills FOR ALL USING (
  auth.uid() = candidate_id
);
CREATE POLICY "Recruiters and admins can view candidate skills" ON public.candidate_skills FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('recruiter', 'admin'))
);

-- 6. Projects
CREATE POLICY "Anyone can view open projects" ON public.projects FOR SELECT USING (status = 'open');
CREATE POLICY "Recruiters can manage own projects" ON public.projects FOR ALL USING (
  auth.uid() = recruiter_id
);
CREATE POLICY "Admins can view all projects" ON public.projects FOR SELECT USING (public.is_admin());

-- 7. Project Requirements
CREATE POLICY "Anyone can view project requirements" ON public.project_requirements FOR SELECT USING (true);
CREATE POLICY "Recruiters can manage own project requirements" ON public.project_requirements FOR ALL USING (
  EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND recruiter_id = auth.uid())
);

-- 8. Match Scores
CREATE POLICY "Candidates can view own match scores" ON public.match_scores FOR SELECT USING (
  auth.uid() = candidate_id
);
CREATE POLICY "Recruiters can view match scores for own projects" ON public.match_scores FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND recruiter_id = auth.uid())
);
CREATE POLICY "Admins can view all match scores" ON public.match_scores FOR SELECT USING (public.is_admin());

-- 9. Fairness Metrics
CREATE POLICY "Recruiters can view fairness for own projects" ON public.fairness_metrics FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.projects WHERE id = project_id AND recruiter_id = auth.uid())
);
CREATE POLICY "Admins can view all fairness metrics" ON public.fairness_metrics FOR SELECT USING (public.is_admin());

-- 10. Audit Logs
CREATE POLICY "Only admins can view audit logs" ON public.audit_logs FOR SELECT USING (public.is_admin());
-- Insert policy normally done by system/triggers, but if via API, restrict to authenticated users performing actions
CREATE POLICY "System can insert audit logs" ON public.audit_logs FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ==========================================
-- TRIGGERS (Auto-sync with Supabase Auth)
-- ==========================================

-- Trigger function to create a public.users row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    COALESCE((new.raw_user_meta_data->>'role')::user_role, 'candidate'::user_role)
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Trigger for updating 'updated_at' columns
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
CREATE TRIGGER set_candidate_updated_at BEFORE UPDATE ON public.candidate_profiles FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
CREATE TRIGGER set_recruiter_updated_at BEFORE UPDATE ON public.recruiter_profiles FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
CREATE TRIGGER set_projects_updated_at BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
