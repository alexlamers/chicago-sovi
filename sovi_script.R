# ========================
# Chicago SoVI (Cook County)
# ========================

# This script pulls American Community Survey 5-year census data to use in the
# construction of a social vulernability index.
#

library(tidycensus)
library(tidyverse)
library(psych)   # PCA
library(scales)  # rescaling

# 1. API key (only run once to install permanently)
# census_api_key("YOUR_API_KEY_HERE", install = TRUE)

# 2. ACS Year
year <- 2022

# 3. Define ACS Variables
vars <- c(
  # --- Socioeconomic ---
  poverty_total = "B17001_001", 
  poverty_below = "B17001_002",
  median_income = "B19013_001",
  unemployed = "B23025_005",
  labor_force = "B23025_003",
  
  # Education (need full set for summing)
  edu_total = "B15003_001",
  edu_002 = "B15003_002", edu_003 = "B15003_003", edu_004 = "B15003_004",
  edu_005 = "B15003_005", edu_006 = "B15003_006", edu_007 = "B15003_007",
  edu_008 = "B15003_008", edu_009 = "B15003_009", edu_010 = "B15003_010",
  edu_011 = "B15003_011", edu_012 = "B15003_012", edu_013 = "B15003_013",
  edu_014 = "B15003_014", edu_015 = "B15003_015", edu_016 = "B15003_016",
  
  # --- Household/Disability ---
  total_pop = "B01001_001",
  # Under 18 (male + female, multiple categories)
  m_under5 = "B01001_003", m_5to9 = "B01001_004", m_10to14 = "B01001_005", m_15to17 = "B01001_006",
  f_under5 = "B01001_027", f_5to9 = "B01001_028", f_10to14 = "B01001_029", f_15to17 = "B01001_030",
  # Over 65 (male + female, multiple categories)
  m_65_66 = "B01001_020", m_67_69 = "B01001_021", m_70_74 = "B01001_022",
  m_75_79 = "B01001_023", m_80_84 = "B01001_024", m_85plus = "B01001_025",
  f_65_66 = "B01001_044", f_67_69 = "B01001_045", f_70_74 = "B01001_046",
  f_75_79 = "B01001_047", f_80_84 = "B01001_048", f_85plus = "B01001_049",
  
  # Disability
  dis_total = "C18108_001",
  dis_with = "C18108_002",
  
  # Single-parent households
  female_sp = "B11003_010",
  male_sp = "B11003_016",
  
  # --- Minority/Language ---
  total_race = "B03002_001",
  white_nonhisp = "B03002_003",
  
  # Limited English proficiency (need multiple)
  lep_spanish_well = "B16005_007", lep_spanish_notwell = "B16005_008",
  lep_indo_well = "B16005_012", lep_indo_notwell = "B16005_013",
  lep_asian_well = "B16005_017", lep_asian_notwell = "B16005_018",
  lep_other_well = "B16005_022", lep_other_notwell = "B16005_023",
  
  # --- Housing/Transport ---
  total_units = "B25024_001",
  multi_10_19 = "B25024_005", multi_20_49 = "B25024_006",
  multi_50plus = "B25024_007", multi_other = "B25024_008", 
  multi_other2 = "B25024_009", multi_other3 = "B25024_010",
  
  crowd_total = "B25014_001",
  crowd_1015 = "B25014_005", crowd_1520 = "B25014_006", crowd_20plus = "B25014_007",
  
  veh_total = "B08201_001",
  no_vehicle = "B08201_002",
  
  rent_total = "B25003_001",
  renters = "B25003_003"
)

# 4. Pull ACS data
county_raw <- get_acs(
  geography = "tract",
  variables = vars,
  state = "IL",
  county = "Cook",
  year = year,
  survey = "acs5"
)

# 5. Reshape to wide; pivots tables so each GEOID is a row, and census variables
# are columns
county_wide <- county_raw %>%
  select(GEOID, NAME, variable, estimate) %>%
  pivot_wider(names_from = variable, values_from = estimate)

# 6. Calculate Indicators
county_indicators <- county_wide %>%
  mutate(
    # --- Socioeconomic ---
    pct_poverty = poverty_below / poverty_total * 100,
    pct_unemployed = unemployed / labor_force * 100,
    pct_no_hs = (edu_002 + edu_003 + edu_004 + edu_005 + edu_006 +
                   edu_007 + edu_008 + edu_009 + edu_010 + edu_011 +
                   edu_012 + edu_013 + edu_014 + edu_015 + edu_016) /
      edu_total * 100,
    
    # --- Household/Disability ---
    under18 = (m_under5 + m_5to9 + m_10to14 + m_15to17 +
                 f_under5 + f_5to9 + f_10to14 + f_15to17),
    over65 = (m_65_66 + m_67_69 + m_70_74 + m_75_79 + m_80_84 + m_85plus +
                f_65_66 + f_67_69 + f_70_74 + f_75_79 + f_80_84 + f_85plus),
    pct_under18 = under18 / total_pop * 100,
    pct_over65 = over65 / total_pop * 100,
    pct_disability = dis_with / dis_total * 100,
    pct_singleparent = (female_sp + male_sp) / total_pop * 100,
    
    # --- Minority/Language ---
    pct_minority = (total_race - white_nonhisp) / total_race * 100,
    lep_total = (lep_spanish_well + lep_spanish_notwell +
                   lep_indo_well + lep_indo_notwell +
                   lep_asian_well + lep_asian_notwell +
                   lep_other_well + lep_other_notwell),
    pct_limited_english = lep_total / total_pop * 100,
    
    # --- Housing/Transport ---
    multiunit_total = multi_10_19 + multi_20_49 + multi_50plus + multi_other + multi_other2 + multi_other3,
    pct_multiunit = multiunit_total / total_units * 100,
    crowded_total = crowd_1015 + crowd_1520 + crowd_20plus,
    pct_crowded = crowded_total / crowd_total * 100,
    pct_no_vehicle = no_vehicle / veh_total * 100,
    pct_renters = renters / rent_total * 100
  )

# 7. Save as CSV
write_csv(county_indicators, "county_indicators.csv")

# Done! Each row = census tract, with all SoVI indicators as % values

# ========================
# Chicago SoVI (Cook County)
# Both Methods,CDC, PCA
# 0–1 scaled
# ========================

library(tidycensus)
library(tidyverse)
library(psych)   # PCA
library(scales)  # rescaling

# Assumes you already have "county_data" from the earlier data pull/indicator script
# (with percentage indicators like pct_poverty, pct_unemployed, etc.)

# ------------------------------------------------
# 1. CDC-Style: Percentiles + Domain Averages
# ------------------------------------------------

# Select indicators only
indicators <- county_indicators %>%
  select(GEOID, NAME,
         pct_poverty, pct_unemployed, pct_no_hs,
         pct_under18, pct_over65, pct_disability, pct_singleparent,
         pct_minority, pct_limited_english,
         pct_multiunit, pct_crowded, pct_no_vehicle, pct_renters)

# Step 1: percentile rank each variable (0–1)
cdc_scores <- indicators %>%
  mutate(across(starts_with("pct_"),
                ~ percent_rank(.) , .names = "p_{.col}"))

# Step 2: domain scores
cdc_scores <- cdc_scores %>%
  mutate(
    dom_ses = rowMeans(select(., p_pct_poverty, p_pct_unemployed, p_pct_no_hs), na.rm = TRUE),
    dom_household = rowMeans(select(., p_pct_under18, p_pct_over65, p_pct_disability, p_pct_singleparent), na.rm = TRUE),
    dom_minority = rowMeans(select(., p_pct_minority, p_pct_limited_english), na.rm = TRUE),
    dom_housing = rowMeans(select(., p_pct_multiunit, p_pct_crowded, p_pct_no_vehicle, p_pct_renters), na.rm = TRUE)
  )

# Step 3: overall SOVI, then rescale to 0–1
cdc_scores <- cdc_scores %>%
  mutate(
    svi_cdc_raw = rowMeans(select(., dom_ses, dom_household, dom_minority, dom_housing), na.rm = TRUE),
    svi_cdc = rescale(svi_cdc_raw, to = c(0,1))
  )

# ------------------------------------------------
# 2. PCA-Style: Z-scores + Principal Components
# ------------------------------------------------

# Prepare z-scored data
zdata <- indicators %>%
  select(starts_with("pct_")) %>%
  scale(center = TRUE, scale = TRUE)

# Run PCA (choose nfactors as you like — here 4 = one per domain approx.)
pca <- principal(zdata, nfactors = 4, rotate = "varimax")
print(pca)

# Extract PCA scores as a plain data frame
pca_scores <- as.data.frame(pca$scores)   # ensures no matrix/list cols
pca_scores <- tibble::rownames_to_column(pca_scores, var = "row_id")

# Add GEOID and NAME back in (preserve row order)
pca_scores <- pca_scores %>%
  bind_cols(indicators %>% select(GEOID, NAME)) %>%
  relocate(GEOID, NAME)

# Weighted sum by variance explained (make sure weights are numeric vector)
weights <- as.numeric(pca$Vaccounted["Proportion Var", ])
raw_mat <- as.matrix(pca_scores %>% select(starts_with("RC")))
sovi_pca_raw <- as.numeric(raw_mat %*% weights)

# Add final PCA SOVI (0–1 scaled)
pca_scores <- pca_scores %>%
  mutate(
   sovi_pca_raw = sovi_pca_raw,
    sovi_pca = scales::rescale(sovi_pca_raw, to = c(0,1))
  )

# ------------------------------------------------
# Cleaning up CDC SVI and PCA SoVI outputs
# ------------------------------------------------

# 1. Narrow down to relevant CDC fields
svi_cdc <- cdc_scores %>%
  select(GEOID, NAME, svi_cdc,
         dom_ses, dom_household, dom_minority, dom_housing)

# 2. Narrow down PCA fields
sovi_pca <- pca_scores %>%
  select(GEOID, NAME, sovi_pca)

# 3. Join them together by GEOID
sovi_both <- svi_cdc %>%
  left_join(select(sovi_pca, GEOID, sovi_pca), by = "GEOID")
  

# ------------------------------------------------
# 4. Save Final Output
# ------------------------------------------------

write_csv(svi_cdc, "svi_cdc.csv")
write_csv(sovi_pca, "sovi_pca.csv")
write_csv(sovi_both, "sovi_pca.csv")

# ------------------------------------------------
# 5. Quick Checks
# ------------------------------------------------

# Correlation between CDC and PCA SoVI
correlation <- cor(sovi_both$svi_cdc, sovi_both$sovi_pca, use = "complete.obs")
print(paste("Correlation between CDC SVI and PCA SoVI:", round(correlation, 3)))

# Scatterplot to visualize agreement
plot(sovi_both$svi_cdc, sovi_both$sovi_pca,
     xlab = "CDC SoVI (0–1)",
     ylab = "PCA SoVI (0–1)",
     main = "CDC SVI vs PCA SoVI",
     pch = 19, col = rgb(0,0,1,0.3))

# Fit regression line
fit <- lm(sovi_pca ~ svi_cdc, data = sovi_both)
abline(fit, col = "red", lwd = 2)

# Extract R²
r2 <- summary(fit)$r.squared

# Add R² with statistical plot label (italic R²)
text(x = min(sovi_both$svi_cdc, na.rm=TRUE),
     y = max(sovi_both$sovi_pca, na.rm=TRUE),
     labels = bquote(R^2 == .(round(r2, 3))),
     pos = 4, col = "red", cex = 1.2)