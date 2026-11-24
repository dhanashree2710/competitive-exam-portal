# KDRT ExamSphere – Competitive Examination Portal

HTML + JavaScript + Bootstrap 5 website. **Supabase is the whole backend.** There's no server code to deploy and no command line: you run one SQL file once, then open the website.

## Setup (5 minutes, browser only)

1. **Supabase → Database → Extensions**: search **`http`** and enable it. The AI features need this.
2. **Supabase → SQL Editor → New query**: paste the whole of **`sql/01_setup_all.sql`** and click **Run**.
   You should see *"KDRT ExamSphere backend installed successfully"*. Your data is **not** deleted.
3. **Groq key** (for AI). Choose one:
   * Sign in as Super Admin → **Settings** → paste the key → **Save** → **Test AI**, **or**
   * run `sql/04_set_groq_key.local.sql` in the SQL Editor (this file is git-ignored).
4. Open the website. The **splash screen** shows first, then the **login** page.
   * Locally: double-click `index.html`, or use VS Code "Live Server".
   * Online: upload the whole folder to any web host (cPanel, Netlify, Vercel, GitHub Pages…).

**Can't sign in as Super Admin?** Edit the email and password at the top of `sql/02_superadmin_password.sql` and run it.
**Want a clean start?** `sql/03_reset_data_keep_superadmin.sql` deletes all data **except** the super admin accounts.

## Keys & Git

| Key | Where it lives | Visible in the browser? |
|---|---|---|
| Groq API key | Private table inside the database (`private.settings`) | ❌ never |
| Supabase service-role key | Not used anywhere | ❌ |
| Supabase anon key | `js/config.js` | ✅ It's Supabase's *public* key. Every table is locked, so it can only call the `api()` function, which checks your login first. |

`js/config.js` is **committed with the site**, so Git-based hosting (GitHub Pages, Netlify, Vercel, cPanel Git) gets it automatically. It holds only the Supabase URL and the public anon key. The real secrets stay out of Git: `sql/*.local.sql` (Groq key) and `.env` are in `.gitignore`. The Groq key lives only inside the database.

## How it is built

```
index.html          splash screen (animated) → login.html
login.html          sign in
verify.html         public scorecard verification (QR code)
pages/*.html        one page per screen, shared sidebar + top bar
css/style.css       design system (Times New Roman, slate & teal theme), animations
js/api.js           calls POST /rest/v1/rpc/api and Supabase Storage
js/ui.js            friendly pop-ups, toasts, forms, loading screen
js/layout.js        login check, role-based drawer grouped by responsibilities
js/crud.js          reusable list/search/add/edit/delete component
js/docs.js          reads PDF / Word / Excel / CSV in the browser
js/export.js        PDF / Excel / CSV downloads and PDF scorecards
js/pages/*.js       logic for each page
sql/01_setup_all.sql   the complete backend (tables locked, api() function, storage rules)
```

## Roles (from your workflow)

**KDRT Super Admin** (everything) → **ATSS College Admin** (own college + its institutes) → **Partner Institute Admin** (own institute) → **Faculty** → **Students**.

## Who does what (the portal flow)

| Stage | Who | Where in the app |
|---|---|---|
| 1. Hierarchy | KDRT Super Admin | **Organizations**: create a college or institute *and its admin login* in one form |
| 2. Structure | College / Institute Admin | **Users** (staff & students, CSV bulk import), **Batches**, **Syllabus** |
| 3. Content | Staff / Faculty | **Question Bank**: manual, image upload, Excel/CSV import, PDF/Word extraction, AI generation, draft → approve |
| 4. Exam build | Staff / Admin | **Exams → Create exam (6-step wizard)** |
| 5. Attempt | Student | **My Exams**: timer, palette, autosave, auto-submit, time per question |
| 6. Learning | Staff + Student | **Assignments**, practicals, **Activities** |
| 7. Intelligence | System | **Engagement** (score 0–100), **Student Insights / My Progress** (strengths, weaknesses, 7-day study plan, AI plan) |
| 8. Output | All roles | **Results**, ranks, **PDF scorecards**, **Reports** (PDF / Excel / CSV), notifications |

Every role only sees its own organization's data. This is enforced inside the database, not just hidden in the menu.

## Features

* **Syllabus**: exam type (JEE Main, NEET UG…) → subject → **unit** → chapter → topic. Import from **Excel/CSV** (columns: subject, unit, chapter, topic, weightage) or from **PDF/Word/text with AI**. The original file is stored in the `syllabus-files` bucket. Imported chapters go through **approve & publish**.
* **Question bank**: MCQ single/multi, true/false, numerical with tolerance, short/long answer, coding, file upload. Use **Insert image** for diagrams (`question-images` bucket) and **📎 media** for images, audio, video or PDF per question (`question-media` bucket). The AI generator works by exam, subject, topic, difficulty and language, or from an uploaded document. Includes draft → review → approved workflow and duplicate checking.
* **6-step exam wizard**:
  1. Details (name, type, duration, schedule)
  2. Syllabus selection (subject → unit → chapter → topic)
  3. Questions, from the bank, random by difficulty mix, AI, Excel/PDF import, or written on the spot
  4. Configuration: marks, negative marking, sections, shuffling
  5. Assign batches or individual students
  6. Preview, then save as draft, schedule, or publish
* **Student exam (CBT)**: server-side timer, palette, mark for review, autosave every 15 s, auto-submit, tab-switch tracking, **time spent on each question**. Scoring runs in the database, and answer keys never reach the browser.
* **Results**: negative marking, rank, percentile, accuracy, subject/chapter/topic analysis, manual grading, per-exam release rule, **PDF scorecard with QR verification** (saved in the `scorecards` bucket).
* **Assignments & practicals**: attachments (`assignment-attachments`), student submissions (`student-submissions`), deadlines, resubmission loop, marks and feedback.
* **Activities**: timed challenges, quizzes and revision with points. Resource files go in `assignment-files`.
* **Monitoring**: login/session/practice events, inactivity rules (3/7/15/30 days), an **engagement score (0–100)** and level (Highly engaged / Engaged / At risk / Inactive), and reminders.
* **Preparation intelligence**: strengths, weaknesses, subject performance, score trend, time per question, an automatic 7-day study plan, and a **personalised AI study plan**.
* **Reports**: exam results, student performance, assignment marks, engagement and the question bank, as **PDF, Excel (.xlsx) or CSV**. Students can export their own results.
* **Announcements** with an image/file attachment (`announcements-media`), a notification centre, audit logs, profile photos (`avatars`) and organization logos.

## Storage buckets (created automatically by the setup SQL)

| Bucket | Used for | Access |
|---|---|---|
| `uploads` | original question papers / documents imported by staff | private |
| `assignment-files` | activity & practical resource files | private |
| `assignment-attachments` | files staff attach to assignments | private |
| `student-submissions` | files students submit | private |
| `syllabus-files` | uploaded syllabus PDFs / Word / Excel | private |
| `scorecards` | generated PDF scorecards | private |
| `question-images` | diagrams inside question text | public link |
| `question-media` | images / audio / video / PDF attached to questions | public link |
| `avatars` | profile photos & organization logos | public link |
| `announcements-media` | announcement attachments | public link |

Uploads only work with a 15-minute ticket from the app. The ticket is issued after checking the user's role, the file type and the size (max 10 MB). Private files open through a 2-minute signed link, and only for people allowed to see them. Public-link files use long random names that can't be guessed.

## Sample data (optional)

After `sql/01_setup_all.sql`, run **`sql/04_sample_data.sql`** in the SQL Editor to fill the portal with realistic data for **Sujata Institute of Information And Technology** (SIIT03, Parihar Chowk, Aundh, Pune; admin Tejas Navgire). It's built around your three organizations and admins, and it's safe to run more than once. It also removes the old `…@siit.demo` and `…@atss.demo` test accounts from the earlier sample file. It adds:

* **Staff:** 4 Sujata faculty (Physics, Chemistry, Mathematics and Biology) plus 1 ATSS faculty member.
* **Students:** 24 Sujata students with roll numbers (`SIIT/JEE/27/001…` and `SIIT/NEET/27/001…`), split across two batches of 12.
* **Syllabus:** JEE Main and NEET UG, organised as subjects → units → chapters → topics.
* **Question bank:** 43 approved questions with answers and explanations.
* **Exams:**
  * *JEE Main Mock Test 1*: completed, with 12 results, ranks and percentiles.
  * *NEET Biology Practice Test*: completed, with 12 results.
  * *JEE Main Mock Test 2*: live now.
  * *NEET UG Full Mock 1*: scheduled.
* **Learning:** two assignments with submissions, and three activities with completion records.
* **Monitoring:** two weeks of login history. Most students are active, a few are at risk and one is inactive, so Engagement, Insights and Study plan show real differences.
* **Communication:** announcements and notifications.

Sample logins (change these passwords after trying them):

| Role | Email | Password |
|---|---|---|
| Faculty (Sujata) | rahul.deshmukh@sujatainstitute.in (Physics), meera.apte@… (Chemistry), sandeep.gore@… (Maths), kavita.bhide@… (Biology) | Faculty@123 |
| Faculty (ATSS) | sneha.joshi@atsscollege.in | Faculty@123 |
| Student (JEE) | aarav.patil@sujatainstitute.in, isha.kulkarni@…, rohan.shinde@… | Student@123 |
| Student (NEET) | ananya.more@sujatainstitute.in, kabir.salunkhe@…, sanika.pawar@… | Student@123 |

The admin accounts (super admin, ATSS admin, Tejas) keep their existing passwords.

### 100 records (optional, one file)

Run **`sql/05_more_data_100.sql`**. It already contains everything in `04_sample_data.sql`, so you only need this one file, and it's safe to run more than once. It brings Sujata Institute up to:

* **Students:** 100, in four batches. JEE Main 2027 – A and B have 12 + 38 students; NEET UG 2027 – A and B have 12 + 38.
* **Questions:** 106 approved, with explanations. New Biology chapters include Circulation, Excretion, Neural and Chemical Coordination, Biomolecules, Photosynthesis, Plant Kingdom and Genetics.
* **Tests:**
  * *JEE Weekly Test 3* and *NEET Weekly Test 2*, both completed by all four batches, with ranks and subject-wise analysis. Students who stopped attending show as absent.
  * The live JEE Mock Test 2 and the scheduled NEET Full Mock 1 are now also assigned to Batch B.
* **Assignments:** two more, with about 80 submissions between them, a mix of graded, pending, late and "needs correction".
* **Other:** activities, two weeks of logins (regular, occasional, away and inactive students), announcements and over 300 notifications.

**ATSS College:** 20 BCA students (`aakanksha.wagh@atsscollege.in`, `atharv.lokhande@atsscollege.in` and so on, password `Student@123`), an aptitude syllabus, one completed aptitude test, one live aptitude test, assignments and an activity.

**For every role:** notifications for admins and faculty, an audit history, and at least one open assignment per course, so no page opens empty.

New student logins follow the pattern `first.last@sujatainstitute.in`, for example `aditi.chavan@sujatainstitute.in` or `abhishek.mane@sujatainstitute.in`. The password is `Student@123`. The Users page lists every student.

**Storage buckets.** These are created by `01_setup_all.sql`: uploads, assignment-files, question-images, avatars, announcements-media, question-media, student-submissions, syllabus-files, assignment-attachments and scorecards. Files appear in them when you upload from the portal, for example question images, avatars, assignment files, submissions, syllabus PDFs and scorecards. SQL can't put real files into storage, so the sample data doesn't include any.

## Students table (full student records)

Students now have their own **`students`** table, separate from the login in `users`. It holds:

* **Enrolment:** roll number, admission number and date, main batch, target exam and status.
* **Personal:** date of birth, gender, blood group, category, nationality, alternate phone, and full address with PIN code.
* **Family:** father's and mother's name and phone, father's occupation and guardian email.
* **Academic:** school or college, board, Class 10 and 12 %, and passing year.
* **Fees:** total, paid, balance and an automatic status (paid, partly paid or pending), plus notes.

It is linked to the other tables:

* `students.user_id → users`: deleting the login deletes the record.
* `organization_id → organizations`, `batch_id → batches` and `exam_category_id → exam_categories`: these are cleared automatically if the linked item is deleted.
* Creating a student user (on the Users page, by bulk import or on the Students page) creates the record automatically.
* Changing a student's organization or roll number updates the record.
* Adding or removing a batch membership updates the student's main batch.

Where to find it in the portal:

* **Students page** (admins, plus faculty for their own batches): search, filters, Excel/CSV export, the full record in tabs (Personal, Family, Academic, Fees, Performance), and an add/edit form split into sections. Only admins can add or edit students.
* **My profile** (students): their own record, with the option to update their address and contact numbers.

**To update an existing database:** run the new `sql/01_setup_all.sql` (safe to re-run; your data is kept), then `sql/05_more_data_100.sql` to fill in full details for the sample students.

## Importing students and questions

* **Students → Import students** (admins):
  * Download the Excel or CSV template, fill one row per student, and upload it (drag and drop works).
  * Only `full_name` and `email` are required; the email is the login ID. The other columns are the same fields as the student record: roll no., admission no., batch (code or name), date of birth, gender, address, parents, school, marks and fees.
  * Passwords come from the file's `password` column if present. Otherwise the import creates one per student (e.g. `Riya@4821`) or uses one common password you choose.
  * Each row creates the login in **users**, the full record in **students** and the batch membership. Existing students (same email) are updated.
  * The last step shows every login ID and password, and rows with problems with the reason. Download the login sheet as Excel, CSV or PDF; passwords are shown only once.
* **Questions → Import questions** (staff):
  * Template columns: `question_text, question_type, option_a…option_e, correct, explanation, exam_category, subject, chapter, topic, difficulty, marks, negative_marks, tags`.
  * Supported types: MCQ (single or multiple), numerical, true/false, short and long answer.
  * Subject, chapter and topic are matched by name. Duplicates and rows without a correct answer are reported, not saved.
  * Save as draft (to review) or approved.

## Other changes in this version

* **Back** returns to the page you came from. The portal keeps its own page history, so it works even when the server hides the referrer.
* **Assignment form:** upload the question paper or worksheet, choose batches and publish in one step.
* **Questions page:** summary tiles (click to filter); each question shows its type, options with the correct one highlighted, syllabus path, level and marks.
* **Engagement** rebuilt: no temporary tables, so it works in every Supabase connection mode. Adds summary tiles (click to filter), level, inactivity and batch charts, search, a batch filter and reminders.
* **Student insights:** a student picker with search, batch filter and sort by score; a line chart for the score trend; links to the full record.
* **Data export** is only for the KDRT super admin. Other admins still see the overview numbers on their dashboard.
* **Clickable cards:** dashboard and page tiles open the matching list, already filtered (e.g. Live now → live exams, Inactive students → engagement, Fees pending → students with pending fees).
* **Charts:** counts use whole-number axes (0, 3, 6, 9, 12).

## Batch details, file uploads and charts

* **Batch details:** on the Batches page, click a batch name (or **Open**) to see everything about it:
  * a banner with the batch code, target exam, dates and description
  * KPI tiles: students, average score, pass rate, submission rate, exams and fees due
  * charts: score distribution, exam averages, subject strength and engagement
  * tabs for students (searchable, filter by engagement), exams with toppers, assignments with submission progress, faculty, activities and announcements
  * a one-click Excel export of the batch
  Faculty can open only the batches they teach.
* **Uploads (all stored in Supabase Storage):**
  * Teachers attach files to assignments (`assignment-attachments`) and add resource files to activities and quizzes (`assignment-files`).
  * Students attach up to 5 files per assignment submission (`student-submissions`).
  * Students can upload an answer file and a note when completing a quiz or activity (`student-submissions`). Teachers see these under **Activities → Responses**.
* **Reports with charts:** every report shows KPI tiles and two to four charts above the data, for example score distribution, pass/fail, top 10, engagement mix, difficulty and subject split, or a student's score trend. The PDF download includes the charts.
* **Built-in charts:** charts are drawn by the portal itself (`js/charts.js`), so they always show, with no extra library to download.
* **Search and filters:** one aligned bar on every list: a rounded search box with a clear (✕) button, a filter pill per field (label inside), **Clear** to reset everything, and a results count.
* **Side drawer:** a slim icon rail by default. Hover it to open it over the page, or click the 📌 pin to keep it open. On phones it is a slide-out drawer.

## Data export and the super admin's overview

* **Data export page** (super admin, college admin and institute admin):
  * Pick an organization, or **All organizations** (super admin only), and choose whether to include its partner institutes.
  * Download one Excel workbook with up to nine sheets: Overview, Staff, Students (full records), Batches, Exams, Results, Assignments, Submissions and Engagement.
  * Preview any sheet first and download it on its own as CSV or PDF.
  * Each organization also has a card with key numbers and a **Download all data** button.
  * Admins can only export their own organizations. Every export is recorded in the audit log.
* **Dashboard (super admin and college admin):** an "Organizations at a glance" table showing students, active students, exams, results, average score, pass rate and fees due for each organization.
* **Results and Reports:** each exam in the picker shows which organization it belongs to.

## Side drawer and devices

* **Sidebar:** the menu is short and grouped by role. The **«** button at the top collapses it to a slim icon strip (hover an icon to see its name). The choice is remembered on each device.
* **Phones and tablets:** the menu becomes a slide-out drawer that closes after you pick a page.
* **Layout:**
  * Tables scroll sideways inside their card.
  * Page headings and buttons stack.
  * Pop-up windows fill the screen on small phones.
* **Tested:** every page for each role at 390 px (phone), 820 px (tablet) and 1400 px (desktop).

## Design system

Colours ("Navy & Saffron"): Navy `#0F1E3D` (sidebar, banners) · Royal blue `#2563EB` (actions, links) · Saffron `#F97316` / Amber `#F59E0B` (highlights, create buttons, AI) · Sky `#0EA5E9` (progress) · Emerald `#10B981` (success) · Rose `#E11D48` (errors) · background `#F4F7FB` with white cards. Every page opens with a navy banner and a saffron icon badge. The dashboard shows each role's numbered **workflow**: ticked steps are done, and the saffron card is the next step. The exam question palette keeps the standard colours: grey for not visited, red for not answered, green for answered, purple for marked.

## Table linking (automatic updates)

The setup SQL links every table with real foreign keys, so changes flow through automatically:

* **Deleting cascades** to child data. Deleting a subject removes its units, chapters and topics; a batch removes its members and exam/assignment links; an exam removes its questions list, assignments, attempts and results; a user removes their sessions, attempts, results and submissions; an assignment removes its attachments and submissions.
* **Optional links are cleared**, not deleted. Deleting a chapter keeps its questions but clears their chapter; deleting a user keeps the exams they created.
* **Protected links:** an organization that still has user accounts can't be deleted (deactivate it instead), and a question used in an exam can't be deleted (archive it instead). You get a clear message in both cases.
* **Automatic updates:**
  * Exam totals (questions and marks) recalculate whenever exam questions change.
  * `updated_at` is set on every edit.
  * Duplicate batch members and duplicate exam questions are blocked.
* **Admin roles follow the organization:** a college's admin is a *College Admin* and an institute's admin is an *Institute Admin*. If an organization's type changes, its admins' role changes with it. Manage admins under **Organizations → Admins** (add, edit, reset password, deactivate, delete). Staff and students see their organization's admin on their dashboard and profile.

## Is my database up to date?

Users never see technical messages. To check that the database runs the latest backend, open Supabase → SQL Editor and run:

```sql
select private.backend_version();
```

It should return **3.2**. If it errors or returns an older number, paste the whole `sql/01_setup_all.sql` and click **Run** (your data is kept). Uploads, organization admins, units and reports need it.

## Troubleshooting

| Message | Fix |
|---|---|
| "The database isn't set up yet…" | Run `sql/01_setup_all.sql` in the SQL Editor. |
| "The app's connection key was rejected…" | Check `SUPABASE_ANON_KEY` in `js/config.js` (Supabase → Project Settings → API). |
| "Couldn't connect to the server…" | Check your internet connection and `SUPABASE_URL` in `js/config.js`. |
| "This website isn't linked to the exam server yet…" | `js/config.js` is missing on the server. Open `https://your-site/js/config.js` in the browser: if it shows "Not found", upload that file into the site's `js` folder. If you deploy through GitHub, make sure the file is committed (older versions of this project listed it in `.gitignore`). |
| "AI needs the http database extension…" | Enable **http** under Database → Extensions, then run the setup SQL again. |
| "AI features are not set up yet…" | Super Admin → Settings → add the Groq key. |
| "File storage isn't set up…" | Run the setup SQL again (it creates the private `uploads` bucket). |
| Anything else | Supabase SQL Editor: `select * from private.error_log order by id desc limit 20;` |

## Ran the setup on the wrong Supabase project?
`sql/UNDO_examportal_from_wrong_database.sql` removes only what this setup added there. It starts in **preview mode** and changes nothing until you switch `v_preview` to `false`. Run `sql/UNDO_safety_check.sql` first if you're unsure. Don't run these on your real KDRT ExamSphere project.
