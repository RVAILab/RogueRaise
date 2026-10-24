# Resources

Shared links and reference material collected by the Saturday 1pm crew. Source: [Rogue Raise SAT 1pm crew](https://docs.google.com/document/d/17W6tKFRqK3c_lsziXXl7nCueyEerjTXgF3T8zIZgfvQ/edit) (Google Doc; converted copy in [`notes/`](notes/2026-10-24-sat-1pm-crew.md)).

## Team Links

| What | Link | Notes |
| --- | --- | --- |
| Common Table (Claude artifact) | <https://claude.ai/artifact/NE6tQ9XAfgQem8NTcPXuDe> | Shared by a team member. |
| Ashland Daily Help | <https://github.com/RVAILab/ashlanddailyhelp> | Public repo. Static PWA (`index.html`, `app.js`, `data.js`, service worker) described as "a community resource hub for Ashland and Jackson County." Has a resource directory plus a provider "pulse" view for reporting service events (meals served, showers, navigation encounters); the pulse data is explicitly fictional demo data. |
| Master spreadsheet | [Ashland Resources for Unhoused People](https://docs.google.com/spreadsheets/d/1-70Gp3q9vkxKxo5vLXFmGrnpjb8kGjNB_DmMnsMzqLQ/edit) | Source of truth for the directory below. Tabs: Start Here, Resource Directory, Needs Confirmation. |
| Full transcript (Otter.ai) | <https://otter.ai/u/_PE83PlsR-zx_NyHN4mwghTZ8Yw> | Requires an Otter login to view. |
| Resource Directory & AI Updates | [`notes/2026-10-24-resource-directory-and-ai-updates.md`](notes/2026-10-24-resource-directory-and-ai-updates.md) | Meeting notes on an AI agent that keeps the directory current from provider newsletters and websites. |
| Provider tools design | [`provider-tools-design/`](provider-tools-design/README.md) | Design and tested Postgres schema for provider sign-up, service posting, counts and Community Pulse publishing in Ashland Daily Help. |

## Hotlines

- **911:** immediate danger or a medical emergency.
- **988:** Suicide & Crisis Lifeline (call or text). <https://988lifeline.org/>
- **211:** local referrals for food, shelter and social services. Dial 211 or 866-698-6155 (Mon–Fri 8am–6pm), text your ZIP (`97520`) to `898211` (Mon–Fri 9am–5pm), or search online at <https://www.211info.org/search/97520/>. Referral only; 211 does not reserve shelter beds.
- **Severe-weather shelter alerts:** text `97520SHELTER` to `888777`.

## First Contact

**OHRA Resource Center:** 541-631-2235, 2350 Ashland St, weekdays 9am–2pm. Resource navigators are the entry point for OHRA shelter, showers and most local referrals. <https://ohrahelps.org/get-help/program-services/>

## Resource Directory

Snapshot of the master spreadsheet as of October 24, 2026. The listings come from web research only; **no provider has been called yet.** Confirm hours, eligibility and availability before referring anyone. "Confirm" in the last column marks a listing with conflicting or secondhand details.

The tables below are condensed. Every column of every tab, including eligibility and notes, is in [`data/`](data/): [`start-here.csv`](data/start-here.csv), [`resource-directory.csv`](data/resource-directory.csv) and [`needs-confirmation.csv`](data/needs-confirmation.csv).

### Food and Meals

| Program | Location | Contact | Schedule | Status |
| --- | --- | --- | --- | --- |
| [ACCESS pantry, First United Methodist Church](https://ohrahelps.org/additional-resources/) | 175 N Main St | Not published | Wed 2–4pm | Confirm |
| [Ashland Community Food Bank](https://ohrahelps.org/additional-resources/) | 560 Clover Ln | 541-488-9544 | Mon–Fri and 3rd Sat 9:30am–12:30pm | Confirm |
| [Ashland Community Peace Meal (Thursday)](https://sojwj.org/2026/02/03/were-all-coming-home-ashland-peace-meal-returns-to-pioneer-hall/) | Pioneer Hall | 541-841-8341 | Thu 3:30pm (doors 3pm) | Reviewed |
| [Ashland Community Peace Meal (Friday)](https://sojwj.org/2026/02/03/were-all-coming-home-ashland-peace-meal-returns-to-pioneer-hall/) | Lithia Park gazebo | 541-841-8341 | Fri 3:30pm | Reviewed |
| [Monday Meals](https://www.211info.org/get-help/food/community-meals/) | Ashland Creek Park; Lithia Park bandshell | Ask OHRA | Mon: Creek Park 4:20pm, bandshell 4:40pm | Confirm |
| [Rogue Food Unites mobile markets](https://ohrahelps.org/additional-resources/) | Rotating | See schedule online | Varies | Confirm |
| [Uncle Food's Diner / Peace House](https://peacehouse.net/uncle-foods-diner/) | Trinity Episcopal parish hall (rear alley) | 541-482-9625 | Tue from 4:30pm | Confirm |

### Showers and Laundry

| Program | Location | Contact | Schedule | Status |
| --- | --- | --- | --- | --- |
| [OHRA Laundry & Shower Trailer](https://ohrahelps.org/get-help/program-services/) | 2350 Ashland St | 541-631-2235 | Tue & Thu 10am–2pm | Reviewed |

### Health

| Program | Location | Contact | Schedule | Status |
| --- | --- | --- | --- | --- |
| [La Clinica mobile health](https://ohrahelps.org/additional-resources/) | Rotating Ashland/Medford stops | 541-512-3922 | Changes weekly | Confirm |
| [Rogue Community Health, Ashland](https://roguecommunityhealth.org/locations/ashland-health-center/) | 99 Central Ave | 541-773-3863 | Mon–Fri 7:30am–6pm | Reviewed |

### Shelter and Housing

| Program | Location | Contact | Schedule | Status |
| --- | --- | --- | --- | --- |
| [OHRA Shelter](https://ohrahelps.org/get-help/program-services/) | 2350 Ashland St | 541-631-2235 | Year-round; navigator intake weekdays | Reviewed |
| [City / OHRA Night Lawn](https://ashlandoregon.gov/homelessservices) | 1175 E Main St | 541-631-2235 | Dusk to dawn; pilot Sep 28, 2026–Mar 30, 2027 | Reviewed |
| [Ashland severe-weather alerts](https://ashlandoregon.gov/homelessservices) | Announced per activation | Text 97520SHELTER to 888777 | Only when activated | Reviewed |
| [Community Works / Dunn House](https://www.community-works.org/shelter/) | Confidential | 541-779-4357 | 24/7 HelpLine | Reviewed |
| [Parker House Project](https://www.ashlandparkerhouse.org/) | Call for intake | 541-500-7381; ashlandparkerhouse@gmail.com | Call for intake | Reviewed |
| [Rogue Retreat](https://rogueretreat.org/get-help/) | 711 E Main St #25, Medford | 541-499-0880 | Mon–Fri 8am–noon, 1–5pm | Reviewed |
| [ACCESS rental assistance](https://accesshelps.org/rental-assistance/) | Call for intake | 541-414-0319 | Call | Reviewed |
| [ACCESS Veterans Services](https://accesshelps.org/veterans-assistance/) | Call for intake | 541-774-4322 | Call | Reviewed |
| [Housing Authority of Jackson County](https://ashlandoregon.gov/885/Housing-Options) | See website | 541-779-5785 | Check waitlist openings | Confirm |
| [St. Vincent de Paul, Ashland chapter](https://ashlandoregon.gov/885/Housing-Options) | Call | 541-708-5650 | Call | Confirm |

### Everyday Essentials

| Program | Location | Contact | Schedule | Status |
| --- | --- | --- | --- | --- |
| [211info](https://www.211info.org/contact-us/) | Remote | 211; text 97520 to 898211 | Text Mon–Fri 9am–5pm | Reviewed |
| [Ashland Library / JCLS Community Resources](https://jcls.org/services/community-resources/) | 410 Siskiyou Blvd | 541-774-6980 | Mon–Thu 10am–6pm; Fri–Sat 10am–5pm | Reviewed |
| [Ashland School District McKinney-Vento](https://www.ashland.k12.or.us/page/mkv-homeless) | Contact Student Services | 541-482-2438; StudentServices@ashland.k12.or.us | School office hours | Reviewed |
| [Center for NonProfit Legal Services](https://cnpls.org/) | Apply online | 541-779-7291 (recorded application info) | Application review | Reviewed |
| [Maslow Project](https://www.maslowproject.com/) | 500 Monroe St, Medford; Ashland outreach | 541-608-6868 | Medford center Mon–Fri 10am–5pm | Reviewed |
| [OHRA Resource Center](https://ohrahelps.org/get-help/program-services/) | 2350 Ashland St | 541-631-2235 | Mon–Fri 9am–2pm | Reviewed |
| [Oregon ONE / ODHS](https://www.oregon.gov/odhs/benefits/pages/contact.aspx) | one.oregon.gov | 800-699-9075 | Phone Mon–Fri 7am–6pm | Reviewed |
| [Rogue Valley Transportation District](https://www.rvtd.org/) | Ashland / Rogue Valley | 541-779-2877 | See live timetable | Reviewed |

### Needs Confirmation

These programs came up in research but their current status is unknown. Don't send anyone without checking first.

- **Other community meals / Night Lawn meals:** Wednesday and weekend times unknown; ask the OHRA front desk.
- **Laundry Love, Ashland:** older location and schedule may be stale. <https://laundrylove.org/find-a-location/>
- **Recovery Cafe:** named in the City assessment; current venue and contact not verified.
- **2200 Ashland St winter shelter:** the 2025 hours are not current; the City is still seeking a partner.
- **First Presbyterian Church car camping:** current operation and openings unconfirmed.
- **Havurah Shir Hadash parking program:** intake and vacancies unconfirmed. <https://havurahshirhadash.org/donate-now/>
- **First Congregational Good Neighbor Program:** current services unconfirmed.
- **Public drinking water, restrooms and charging:** no verified public-access map found.

## Background Reading

- [City of Ashland Homeless Services](https://ashlandoregon.gov/homelessservices)
- [City of Ashland Homeless Services Assessment Report (PDF)](https://ashlandoregon.gov/DocumentCenter/View/2627/Homeless-Services-Assessment-Report-PDF)
- [OHRA additional resources](https://ohrahelps.org/additional-resources/)
