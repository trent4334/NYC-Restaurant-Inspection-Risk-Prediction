clean_restaurant_data <- function(data){
  if(isFALSE(tibble::is_tibble(data))){
    stop("all_data should be a tibble")
  }
  cleaned_data <- all_data %>%
    select(CAMIS, BORO, `CUISINE DESCRIPTION`, ACTION, `VIOLATION CODE`, `CRITICAL FLAG`,
           SCORE, GRADE, `INSPECTION TYPE`, `INSPECTION DATE`) %>%
    
    rename(
      id = CAMIS,
      borough = BORO,
      cuisine = `CUISINE DESCRIPTION`,
      action = ACTION,
      code = `VIOLATION CODE`,
      critical = `CRITICAL FLAG`,
      score = SCORE,
      grade = GRADE,
      inspection_type = `INSPECTION TYPE`
    ) %>%
    
    mutate(
      inspection_date = mdy(`INSPECTION DATE`),
      inspection_year = year(inspection_date)
    ) %>%
    select(-`INSPECTION DATE`) %>%
    
    mutate(
      action = recode(action,
                      `Establishment Closed by DOHMH. Violations were cited in the following area(s) and those requiring immediate action were addressed.` = "closed",
                      `Establishment re-closed by DOHMH` = "re-closed",
                      `Establishment re-opened by DOHMH` = "re-opened",
                      `No violations were recorded at the time of this inspection.` = "no violations",
                      `Violations were cited in the following area(s).` = "violations"
      ),
      inspection_type = recode(inspection_type,
                               `Cycle Inspection / Compliance Inspection` = "cycle-compliance",
                               `Cycle Inspection / Initial Inspection` = "cycle-initial",
                               `Cycle Inspection / Re-inspection` = "cycle-re-inspection",
                               `Cycle Inspection / Reopening Inspection` = "cycle-reopening",
                               `Cycle Inspection / Second Compliance Inspection` = "cycle-second-compliance",
                               `Pre-permit (Non-operational) / Compliance Inspection` = "pre-permit-nonop-compliance",
                               `Pre-permit (Non-operational) / Initial Inspection` = "pre-permit-nonop-initial",
                               `Pre-permit (Non-operational) / Re-inspection` = "pre-permit-nonop-re-inspection",
                               `Pre-permit (Non-operational) / Second Compliance Inspection` = "pre-permit-nonop-second-compliance",
                               `Pre-permit (Operational) / Compliance Inspection` = "pre-permit-op-compliance",
                               `Pre-permit (Operational) / Initial Inspection` = "pre-permit-op-initial",
                               `Pre-permit (Operational) / Re-inspection` = "pre-permit-op-re-inspection",
                               `Pre-permit (Operational) / Reopening Inspection` = "pre-permit-op-reopening",
                               `Pre-permit (Operational) / Second Compliance Inspection` = "pre-permit-op-second-compliance"
      )
    ) %>%
    
    filter(
      !is.na(borough),
      !is.na(score),
      score >= 0,
      !inspection_type %in% c(
        "Calorie Posting / Re-inspection",
        "Inter-Agency Task Force / Re-inspection",
        "Smoke-Free Air Act / Re-inspection",
        "Administrative Miscellaneous / Re-inspection",
        "Trans Fat / Re-inspection",
        "Inter-Agency Task Force / Initial Inspection"
      )
    ) %>%
    
    group_by(id, inspection_date) %>%
    mutate(score = max(score, na.rm = TRUE)) %>%
    ungroup()
  
  return(cleaned_data)
}

make_initial_cycle_data <- function(cleaned_data){
  if(isFALSE(tibble::is_tibble(cleaned_data))){
    stop("cleaned_data should be a tibble")
  }
  
  initial_cycle_data <- cleaned_data %>%
    filter(
      inspection_type == "cycle-initial",
      inspection_year %in% c(2017, 2018, 2019)
    ) %>%
    
    group_by(id, inspection_date) %>%
    
    summarize(
      borough = first(borough),
      cuisine = first(cuisine),
      inspection_year = first(inspection_year),
      outcome = any(score >= 28, na.rm = TRUE), 
      .groups = "drop"
    )
  
  return(initial_cycle_data)
}


make_features <- function(initial_cycle_data, cleaned_data){
  if(isFALSE(tibble::is_tibble(initial_cycle_data))){
    stop("initial_cycle_data should be a tibble")
  }
  if(isFALSE(tibble::is_tibble(cleaned_data))){
    stop("cleaned_data should be a tibble")
  }
  # Rename initial_cycle_data to restaurant_data
  restaurant_data <- initial_cycle_data %>%
    mutate(
      month = month(inspection_date, label = TRUE, abbr = TRUE), # Add month feature
      weekday = wday(inspection_date, label = TRUE, abbr = TRUE) # Add weekday feature
    )
  
  historical_features <- cleaned_data %>%
    left_join(restaurant_data, by = "id", suffix = c("_historical", "_initial")) %>%
    filter(inspection_date_historical < inspection_date_initial) %>%
    group_by(id, inspection_date_initial) %>%
    summarize(
      num_previous_low_inspections = sum(score < 14, na.rm = TRUE),
      num_previous_med_inspections = sum(score >= 14 & score < 28, na.rm = TRUE),
      num_previous_high_inspections = sum(score >= 28, na.rm = TRUE),
      num_previous_closings = sum(action %in% c("closed", "re-closed"), na.rm = TRUE),
      .groups = "drop"
    )
  
  restaurant_data <- restaurant_data %>%
    left_join(historical_features, by = c("id", "inspection_date" = "inspection_date_initial")) %>%
    mutate(
      num_previous_low_inspections = replace_na(num_previous_low_inspections, 0),
      num_previous_med_inspections = replace_na(num_previous_med_inspections, 0),
      num_previous_high_inspections = replace_na(num_previous_high_inspections, 0),
      num_previous_closings = replace_na(num_previous_closings, 0)
    )
  
  return(restaurant_data)
}


fit_models <- function(restaurant_data){
  if(isFALSE(tibble::is_tibble(restaurant_data))){
    stop("restaurant_data should be a tibble")
  }
    restaurant_data <- restaurant_data %>%
    mutate(
      month = as.factor(month),
      weekday = as.factor(weekday),
      outcome = as.factor(outcome)
    )
  
  train <- restaurant_data %>% filter(inspection_year %in% c(2017, 2018))
  test <- restaurant_data %>% filter(inspection_year == 2019)
  
  outcomes <- test$outcome
  
  logistic_model <- glm(
    outcome ~ cuisine + borough + month + weekday,
    data = train,
    family = binomial()
  )
  
  logistic_predictions <- predict(logistic_model, newdata = test, type = "response")
  
  pred_logistic <- prediction(logistic_predictions, as.numeric(outcomes) - 1)
  auc_logistic <- performance(pred_logistic, measure = "auc")@y.values[[1]]
  
  rf_model <- ranger(
    outcome ~ cuisine + borough + month + weekday + 
      num_previous_low_inspections + num_previous_med_inspections +
      num_previous_high_inspections + num_previous_closings,
    data = train,
    num.trees = 1000,
    respect.unordered.factors = TRUE,
    probability = TRUE
  )
  
  rf_predictions <- predict(rf_model, data = test)$predictions[, 2]
  
  pred_rf <- prediction(rf_predictions, as.numeric(outcomes) - 1)
  auc_rf <- performance(pred_rf, measure = "auc")@y.values[[1]]
  
  return(list(
    outcomes = as.numeric(outcomes) - 1,
    logistic_predictions = logistic_predictions,
    rf_predictions = rf_predictions,
    auc_logistic = auc_logistic,
    auc_rf = auc_rf
  ))
}


################## Test functions: do not edit the code below ##################
test_clean_restaurant_data <- function(){
  testthat::test_that('Checking that `clean_restaurant_data()` exists', {
    testthat::expect_true(exists('clean_restaurant_data'))
  })
  
  testthat::test_that('Checking that clean_restaurant_data() returns a tibble', {
    testthat::expect_true(tibble::is_tibble(cleaned_data))
  })
  
  testthat::test_that('Checking that column names are correct', {
    testthat::expect_named(cleaned_data, 
                           expected = c("id", "borough", "cuisine", 
                                        "action", "code", "critical",
                                        "score", "grade", "inspection_type",
                                        "inspection_date", "inspection_year"
                           ), 
                           ignore.order = TRUE)
  })
  
}

test_make_initial_cycle_data <- function(){
  testthat::test_that('Checking that `make_initial_cycle_data()` exists', {
    testthat::expect_true(exists('make_initial_cycle_data'))
  })
  
  testthat::test_that('Checking that make_initial_cycle_data() returns a tibble', {
    testthat::expect_true(tibble::is_tibble(initial_cycle_data))
  })
  
  testthat::test_that('Checking that column names are correct', {
    testthat::expect_named(initial_cycle_data, 
                           expected = c("id", "inspection_date", "borough", 
                                        "cuisine", "inspection_year", 
                                        "outcome"), 
                           ignore.order = TRUE)
  })
}


test_make_features <- function(){
  testthat::test_that('Checking that `make_features()` exists', {
    testthat::expect_true(exists('make_features'))
  })
  
  testthat::test_that('Checking that make_features() returns a tibble', {
    testthat::expect_true(tibble::is_tibble(restaurant_data))
  })
  
  testthat::test_that('Checking that column names are correct', {
    testthat::expect_named(restaurant_data, 
                           expected = c("id", "inspection_date", "borough", 
                                        "cuisine", "inspection_year", 
                                        "outcome", 'month', 'weekday', 
                                        "num_previous_low_inspections", 
                                        "num_previous_med_inspections", 
                                        "num_previous_high_inspections", 
                                        "num_previous_closings"), 
                           ignore.order = TRUE)
  })
  
}

test_fit_models <- function(){
  testthat::test_that('Checking that `fit_models()` exists', {
    testthat::expect_true(exists('fit_models'))
  })
  
  testthat::test_that('Checking that `fit_models()` returns a list', {
    testthat::expect_true(
      is.list(output)
    )
  })
  
  testthat::test_that('Checking that `fit_models()` elements have correct names', {
    testthat::expect_named(
      object = output, 
      expected = c('logistic_predictions', 'rf_predictions', 'auc_logistic', 'auc_rf', 'outcomes'), 
      ignore.order = TRUE
    )
  })
  
}
