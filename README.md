# FarmLedger: Contract Broiler Profitability and Statement Automation

A data project built from real growing charge statements of a contract broiler (meat chicken) farm in Telangana, India. It turns paper statements into a checked PostgreSQL database, shows what the farmer really earns after his own costs, and (planned) automates adding new statements.

Stack: Excel (source data) -> PostgreSQL -> Power BI, with n8n for automation and weather data.

## Business questions
1. Why did some batches perform badly, and when did the losses happen: first week, first 30 days, or after day 30?
2. What does the farmer really earn per batch after his own costs and manure income, where is the break-even point, and how much of his costs does manure income cover?
3. How much of the payout is lost to deductions, and how much of that is purchases made through the company (fans, materials) rather than performance penalties?
4. How do season and weather relate to batch results? (Patterns only, based on 7 batches.)
5. How much does a disease-affected batch cost the farmer compared with a healthy one?
6. How accurately, and how much faster, can a new statement be added using the automated flow?

## Done so far
- Master Excel file, checked cell by cell against the paper statements
- PostgreSQL schema (dimension and fact tables, keys, check rules)
- Data load script 
- Data quality checks (payout, feed, cost, bird counts, mortality %, FCR): all batches pass
- KPI view and farmer profit view (net payable - own costs + manure income)
- Calendar table with seasons

## Planned
- Daily weather data (Open-Meteo, fetched with n8n)
- Power BI dashboard
- n8n flow: AI reads a new statement, checks it, then saves it or sends it to a review list

## Folders
- `data/` source Excel files (private data stays out of GitHub)
- `sql/` table definitions, load scripts, views, checks
- `n8n/` exported automation workflows (passwords removed)
- `powerbi/` dashboard file and screenshots
- `docs/` architecture picture, data dictionary, assumptions

## Limits
- Only 7 batches from one farm, so no predictive modelling
- Farm costs are the farmer's rounded estimates (approximately not exactly)
- Disease batches are verified by the division supervisors upon checking, but not lab tested.
- Net payable is after TDS; profit excludes repairs, loan payments, depreciation and family labour

## About AI assistance
AI assistants helped draft and review code. Data collection, checking, design decisions and analysis are my own.