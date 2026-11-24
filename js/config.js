// Your Supabase connection. Commit this file and upload it with the site.
// The anon key is a PUBLIC key by Supabase design (every visitor's browser receives it);
// all tables are locked, so it can only call the secure api() function.
// Secrets (Groq key, database password, service_role key) are NOT here – never put them in this file.
window.APP_CONFIG = {
  SUPABASE_URL: "https://lgkxgcmkmoigbiswmexy.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxna3hnY21rbW9pZ2Jpc3dtZXh5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUwNzQxMDYsImV4cCI6MjExMDY1MDEwNn0.M3NXtsto4-OvwrSVvz1J2k85m-fV2T5CUFSunmXMXzM",
  APP_NAME: "KDRT ExamSphere"
};
