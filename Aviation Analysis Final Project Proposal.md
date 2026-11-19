# Aviation Analysis: Final Project Proposal

## Questions and Goals

We're asking four questions about the airline industry and the two main aircraft makers. Two of them need models.

1. How much did COVID affect airlines, by region and business model, and how fast did they recover? This question can be answered primarily through
EDA, looking at trends in the data before vs. after COVID. We can then create a timeplot to demonstrate this change.
2. Which factors drive an airline's operating income and can we predict that income? We'll model it from fleet size, business model, passengers, 
load factor, and region, using linear regression and XGBoost.
3. Which maker and aircraft family carries the most order risk? We'll compare Boeing, Airbus, and COMAC, and use a random forest to test whether it can flag years with negative net orders.
4. How do incident rates compare by region? We will again use EDA and graphing to answer/visualize this question.

Goal: A measured COVID hit for each region and business model, a ranked list of income drivers, and a clear view of order risk and its limits. Thus, we will be 
able to both demonstrate clear trends in the data as well as make predictions from it.


## Data Acquisition

The data is the Kaggle set Global Aviation Industry 2010-2026 by sergionefedov: https://www.kaggle.com/datasets/sergionefedov/global-aviation-industry-2010-2026. 
The author takes anchor values from airline 10-K filings, Boeing and Airbus order reports, IATA traffic reports, and the ASN safety database. 
Much of the year-to-year data is modeled. Revenue is interpolated between filings, and regional traffic is generated from anchor years.
It is composed of 5 separate CSV files that will be joined for analysis and modeling.

| File | Rows | Content |
| --- | --- | --- |
| airline\_financials.csv | 497 | 30 airlines: revenue, margin, fleet |
| fleet\_orders.csv | 86 | Boeing, Airbus, COMAC, Embraer orders and backlog |
| passenger\_traffic.csv | 1,176 | 6 regions, monthly RPK and ASK |
| route\_performance.csv | 400 | 40 routes: passengers, fares, revenue |
| aviation\_incidents.csv | 40 | Major incidents and fatalities |
