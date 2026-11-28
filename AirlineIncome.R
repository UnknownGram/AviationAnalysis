library("tidyverse")
install.packages("tidymodels")
library("tidymodels")


financials = read.csv("/cloud/project/airline_financials.csv")
financials




Delta <- financials |> filter(airline_name == "Delta Air Lines")
Delta |> 
  ggplot(aes(x = year, y = operating_income_usd_bn)) + 
  geom_line()

Delta <- financials |> filter(airline_name == "Delta Air Lines")
Delta |> 
  ggplot(aes(x = year, y = operating_income_usd_bn)) + 
  geom_line()


financials |> 
  ggplot(aes(x = year, y = operating_income_usd_bn, color = airline_name)) + 
  geom_line() +
  geom_point() # Optional: makes individual years easier to read


# EDA

# 1. Check for duplicates in airline-names and code
financials |> distinct(airline_name, iata_code) |> count(airline_name) |> filter(n > 1)  # same name, two codes
financials |> distinct(airline_name, iata_code) |> count(iata_code) |> filter(n > 1)     # same code, two names
n_distinct(financials$airline_name)  # should be 30

# 2. Check for duplicate airline-years
financials |> count(airline_name, year) |> filter(n > 1)

# 3. Build the full grid and find the absent rows
all_rows <- expand_grid(
  airline_name = unique(financials$airline_name),
  year = 2010:2026
)

missing_rows <- anti_join(all_rows, financials, by = c("airline_name", "year")) |>
  arrange(airline_name, year)

missing_rows
nrow(missing_rows)  # should be 13 if the file is 510 rows minus 497

# 1 = present, 0 = missing, one row per airline
 missingData <- financials |>
  count(airline_name, year) |>
  pivot_wider(names_from = year, values_from = n, values_fill = 0)

print(missingData)
# I found that Riyadh Air is missing 13 data/years because Riyadh Air was created in 2023

# NEXT getting features: 

# I will be doing the log cause the data is heavily skewed

# Prior-year values, matched by year rather than row position
prior <- financials |>
  transmute(
    airline_name,
    year = year + 1,
    prev_income = operating_income_usd_bn,
    prev_passengers = passengers_carried_m
  )

model_data <- financials |>
  left_join(prior, by = c("airline_name", "year")) |>
  transmute(
    airline_name,
    year,
    target = operating_income_usd_bn,        
    business_model = factor(business_model),
    region = factor(region),
    log_fleet = log(fleet_size_est),
    log_passengers = log(passengers_carried_m),
    load_factor = load_factor_pct,
    prev_income,
    prev_passengers,
    covid_year = year %in% 2020:2021
  )

# NEED TO FIX. Riyadh Air Shows -INF because it was created in 2023.
model_data |> filter(if_any(everything(), is.na))




# Modeling

install.packages("tidymodels")
install.packages("car")
library(tidymodels)  # rsample, recipes, parsnip, yardstick
library(car)         # vif()

model_clean <- model_data |>
  mutate(covid_year = as.integer(covid_year)) |>
  drop_na()

nrow(model_clean)  # check how many rows survive

# Five folds, each airline in exactly one fold
set.seed(42)
folds <- group_vfold_cv(model_clean, group = airline_name, v = 5)

lm_recipe <- recipe(
  target ~ business_model + region + log_fleet + log_passengers +
    load_factor + prev_income + prev_passengers + covid_year,
  data = model_clean
) |>
  step_dummy(all_nominal_predictors())

lm_wf <- workflow() |>
  add_recipe(lm_recipe) |>
  add_model(linear_reg() |> set_engine("lm"))

lm_res <- fit_resamples(
  lm_wf, folds,
  metrics = metric_set(rmse, rsq)
)

collect_metrics(lm_res)

# Collinearity check on the full data
lm_fit <- lm(
  target ~ business_model + region + log_fleet + log_passengers +
    load_factor + prev_income + prev_passengers + covid_year,
  data = model_clean
)
vif(lm_fit)  # values above about 5 to 10 mean the predictor is redundant

# Same model without 2020-2021, to see how much COVID drives the fit
model_clean |>
  filter(covid_year == 0) |>
  lm(formula(lm_fit), data = _) |>
  summary()


# MODELING WITH XGBOOST

# 1. Split whole airlines into train and test (80/20)
set.seed(42)
airline_split <- group_initial_split(model_clean, group = airline_name, prop = 0.8)
airline_train <- training(airline_split)
airline_test  <- testing(airline_split)

# 2. Cross-validation on the training airlines only
airline_cv <- group_vfold_cv(airline_train, group = airline_name, v = 5)

# 3. Recipe
xgb_rec <- recipe(
  target ~ business_model + region + log_fleet + log_passengers +
    load_factor + prev_income + prev_passengers + covid_year,
  data = airline_train
) %>%
  step_dummy(all_nominal_predictors())

# 4. Untuned XGBoost
xgb_fit <- workflow() %>%
  add_recipe(xgb_rec) %>%
  add_model(boost_tree(mode = "regression", trees = 100) %>% set_engine("xgboost")) %>%
  fit(airline_train)

xgb_test <- airline_test %>%
  mutate(pred = predict(xgb_fit, airline_test)$.pred)

sqrt(mean((xgb_test$target - xgb_test$pred)^2)) 

# 5. Tuned XGBoost, tuned only on the training airlines
xgb_spec <- boost_tree(
  mode = "regression",
  trees = tune(),
  tree_depth = tune(),
  learn_rate = tune(),
  min_n = tune(),
  sample_size = tune()
) %>%
  set_engine("xgboost")

xgb_wf <- workflow() %>%
  add_recipe(xgb_rec) %>%
  add_model(xgb_spec)

set.seed(42)
xgb_res <- xgb_wf %>%
  tune_grid(resamples = airline_cv, grid = 30, metrics = metric_set(rmse, rsq))

show_best(xgb_res, metric = "rmse")
best_xgb <- select_best(xgb_res, metric = "rmse")

# 6. Final test score on the held-out airlines
xgb_final <- xgb_wf %>%
  finalize_workflow(best_xgb) %>%
  last_fit(airline_split, metrics = metric_set(rmse, rsq))

collect_metrics(xgb_final)

# 7. Linear baseline on the same split, for a fair comparison
lm_final <- workflow() %>%
  add_recipe(xgb_rec) %>%
  add_model(linear_reg()) %>%
  last_fit(airline_split, metrics = metric_set(rmse, rsq))

collect_metrics(lm_final)

# R Square for Xgboost is 84.3% while R Square for linear Regression is 73.9%


