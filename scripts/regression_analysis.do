// ssc install egenmore

set matsize 11000

cd "/Users/nj995/dropbox/projects/2018_helios/"

global date "20181124"
global regression_output "output/regression_results/"

import delimited "data/regression_dataset.csv", clear

preserve
	keep funder_name grant_id
	duplicates drop
	tab funder_name
restore
preserve
	keep funder_name rsr_id
	duplicates drop
	tab funder_name
restore


************************************
************************************
* DATA CLEANUP:
************************************
************************************

* Temp
drop rsr_affiliation_id
drop cso_*
drop rcdc_*

* Create Time Dummies
gen time_pos = year - start_year

* Create Career Age Squared
gen rsr_career_age_2 = rsr_career_age*rsr_career_age

* Drop crossfunds:
bysort grant_id: egen crossfund = nvals(funder_name)
drop if crossfund > 1
drop crossfund

* Drop researchers funded by different counterfactual agencies
bysort rsr_id: egen multiple_funders = nvals(funder_name)
drop if multiple_funders > 1
drop multiple_funders
preserve
	keep funder_name grant_id
	duplicates drop
	tab funder_name
restore
preserve
	keep funder_name rsr_id
	duplicates drop
	tab funder_name
restore

* Keep only first grant for every researcher:
sort rsr_id start_date grant_id year
duplicates drop rsr_id time_pos, force
preserve
	keep funder_name grant_id
	duplicates drop
	tab funder_name
restore
preserve
	keep funder_name rsr_id
	duplicates drop
	tab funder_name
restore


* Keep only is there is an affiliation
drop if rsr_affiliation == ""
preserve
	keep funder_name grant_id
	duplicates drop
	tab funder_name
restore
preserve
	keep funder_name rsr_id
	duplicates drop
	tab funder_name
restore


* Create Funder Category, Person Category, Researcher Country, Researcher Affiliation
egen funder_id = group(funder_name), label
egen person_id = group(rsr_id)
egen rsr_country_id = group(rsr_country)
egen rsr_affiliation_id = group(rsr_affiliation)
egen orcid_confirmed_cat = group(orcid_confirmed), label
egen gender_cat = group(rsr_gender), label

*create dummy for INCA vs. any other
gen funder_inca=(funder_name=="INCa/INSERM/DGOS")

* Create Diff in Diff estimator
gen post_flag = (status=="post")
// gen during_flag = (status=="focal")

* Create Diff in Diff Year estimators
gen post_year_temp = time_pos if time_pos>0
replace post_year_temp = 0 if post_year_temp == .
tostring post_year_temp, replace
gen post_year_temp_2 = "post_"+post_year_temp
egen post_year = group(post_year_temp_2), label
drop post_year_temp*

gen year_temp = time_pos
tostring year_temp, replace
gen year_temp_2 = "post_"+year_temp if time_pos>0
replace year_temp_2 = "pre_"+year_temp if time_pos<=0
egen pre_post_year = group(year_temp_2), label
drop year_temp*

gen years_since_pub = 2018-year
gen citations_per_pub_per_year = citations_per_pub/years_since_pub

************************************
************************************
* REGRESSIONS:
************************************
************************************

local grant_controls funding_len funding_amount nb_rsrs
local dependant_vars /*nb_pubs nb_collabs nb_collab_countries citations_per_pub citations_per_pub_per_year*/ nb_pubs_in_topic
local post_award_types post_flag /*i.post_year i.b10.pre_post_year*/
local weight_vars 1 weight

foreach depvar in `dependant_vars'{

	eststo clear
	capture log close
	log using "output/regression_results/${date}_`depvar'.log", replace
	
		foreach post_award in `post_award_types'{
			
			foreach weight_var in `weight_vars'{
				* First Regression
				eststo: regress `depvar' `post_award'##i.funder_id i.orcid_confirmed_cat i.start_year [aweight=`weight_var'], robust				
				estadd local YearFE "Yes"
				estadd local AffiliationFE "No"
				estadd local ResearcherFE "No"
			
				* Second Regression: add researcher gender
				eststo: regress `depvar' `post_award'##i.funder_id i.orcid_confirmed_cat i.b3.gender_cat i.start_year [aweight=`weight_var'], robust
				estadd local YearFE "Yes"
				estadd local AffiliationFE "No"
				estadd local ResearcherFE "No"
				
				* Third Regression: add career age and career age squared
				eststo: regress `depvar' `post_award'##i.funder_id i.orcid_confirmed_cat i.b3.gender_cat c.rsr_career_age c.rsr_career_age_2 i.start_year [aweight=`weight_var'], robust
				estadd local YearFE "Yes"
				estadd local AffiliationFE "No"
				estadd local ResearcherFE "No"
				
				* Fourth Regression: add researcher affiliation (and remove country)
// 				xtset rsr_affiliation_id
// 				eststo: xtreg `depvar' `post_award'##i.funder_id c.rsr_career_age c.rsr_career_age_2 i.orcid_confirmed_cat i.b3.gender_cat i.start_year [aweight=`weight_var'], fe robust
// 				estadd local CountryFE "No"
// 				estadd local AffiliationFE "Yes"
// 				estadd local ResearcherFE "No"
				
				* Final Regression: remove all controls and put researcher fixed effects
				xtset person_id
				eststo: xtreg `depvar' `post_award'##i.funder_id [aweight=`weight_var'], fe robust
				estadd local YearFE "Yes"
				estadd local AffiliationFE "Yes"
				estadd local ResearcherFE "Yes"
			
			}
			
		}

	capture log close
	esttab using "${regression_output}${date}_`depvar'.csv", se star(* .1 ** .05 *** .01) scalars(YearFE AffiliationFE ResearcherFE) nogaps label b(3) se(3) long append
		
	eststo clear
		
}

capture log close

* Journal as LHV: Google journal quality
* Look at top 100 and flag them and leave the rest as other
* 1-0 flag with pubications in top 50, 100 journals.
* Later, run again everything for just pubtype == article.



// drop funder_id
// gen funder_id=1 if funder_name=="Cancer Research UK"
// replace funder_id=2 if funder_name=="INCa/INSERM/DGOS"
// replace funder_id=3 if funder_name=="National Cancer Institute"
// replace funder_id=4 if funder_name=="National Health and Medical Research Council"
// replace funder_id=5 if funder_name=="Wellcome Trust"

// decode pre_post_year, gen(period_temp)
// 	gen period_6=(period_temp=="pre_0")
// forvalues i=2/5{
// 	local j=`i'-6
// 	gen period_`i'=(period_temp=="pre_`i'")
// }
// forvalues i=1/5{
// 	local j=`i'+6
// 	gen period_`j'=(period_temp=="post_`i'")
// }

// tab funder_id, gen(funder_id_)
// drop pre_post_year period_temp funder_id_1

// forvalues i=2/11{
// 	forvalues j=2/5{
// 		gen int_period_`i'_x_funder_`j'=(period_`i'==1&funder_id_`j')
// 	}
// }


// local grant_controls funding_len funding_amount nb_rsrs
// local dependant_vars nb_pubs nb_collabs nb_collab_countries citations_per_pub citations_per_pub_per_year
// local post_award_types post_flag /*i.post_year i.b10.pre_post_year*/
// local weight_vars 1 weight

// foreach depvar in `dependant_vars'{

// 	eststo clear
// 	capture log close
// 	log using "output/regression_results/${date}_`depvar'.log", replace
	
// 		foreach post_award in `post_award_types'{
			
// 			foreach weight_var in `weight_vars'{
// // 				* First Regression
// // 				eststo: regress `depvar' `post_award'##i.funder_id i.orcid_confirmed_cat i.start_year [aweight=`weight_var'], robust				
// // 				estadd local YearFE "Yes"
// // 				estadd local AffiliationFE "No"
// // 				estadd local ResearcherFE "No"
			
// // 				* Second Regression: add researcher gender
// // 				eststo: regress `depvar' `post_award'##i.funder_id i.orcid_confirmed_cat i.b3.gender_cat i.start_year [aweight=`weight_var'], robust
// // 				estadd local YearFE "Yes"
// // 				estadd local AffiliationFE "No"
// // 				estadd local ResearcherFE "No"
				
// // 				* Third Regression: add career age and career age squared
// // 				eststo: regress `depvar' `post_award'##i.funder_id i.orcid_confirmed_cat i.b3.gender_cat c.rsr_career_age c.rsr_career_age_2 i.start_year [aweight=`weight_var'], robust
// // 				estadd local YearFE "Yes"
// // 				estadd local AffiliationFE "No"
// // 				estadd local ResearcherFE "No"
				
// 				* Fourth Regression: add researcher affiliation (and remove country)
// // 				xtset rsr_affiliation_id
// // 				eststo: xtreg `depvar' `post_award'##i.funder_id c.rsr_career_age c.rsr_career_age_2 i.orcid_confirmed_cat i.b3.gender_cat i.start_year [aweight=`weight_var'], fe robust
// // 				estadd local CountryFE "No"
// // 				estadd local AffiliationFE "Yes"
// // 				estadd local ResearcherFE "No"
				
// 				* Final Regression: remove all controls and put researcher fixed effects
// 				xtset person_id
// 				eststo: xtreg `depvar' period_* int_* [aweight=`weight_var'], fe robust
// 				estadd local YearFE "Yes"
// 				estadd local AffiliationFE "Yes"
// 				estadd local ResearcherFE "Yes"
			
// 			}
			
// 		}

// 	capture log close
// 	esttab using "${regression_output}${date}_`depvar'.csv", se star(* .1 ** .05 *** .01) scalars(YearFE AffiliationFE ResearcherFE) nogaps label b(3) se(3) long append
		
// 	eststo clear
		
// }

// capture log close





import delimited "output/topics_for_regression.csv", clear

bysort agency: egen tot_pubs = sum(pubs)
gen share = pubs/tot_pubs
replace share = 0 if share == .
replace share = 100*share

egen rcdc_id =  group(rcdc), label
egen agency_id =  group(agency), label

eststo clear
capture log close
log using "${regression_output}${date}_cso_topics.log", replace
foreach cso_code in 1 2 3 4 5 6{
	preserve
		keep if cso == `cso_code'
		eststo: regress share i.agency_id i.rcdc_id, robust
	restore	
}
capture log close
esttab using "${regression_output}${date}_cso_topics.csv", se star(* .1 ** .05 *** .01) nogaps label b(3) se(3) long append
eststo clear

// drop share_2
// gen share_2 = log(share+sqrt(share*share+1))

// eststo clear
// capture log close
// log using "${regression_output}${date}_cso_topics_hyper.log", replace
// foreach cso_code in 1 2 3 4 5 6{
// 	preserve
// 		keep if cso == `cso_code'
// 		eststo: regress share i.agency_id i.rcdc_id, robust
// 	restore	
// }
// capture log close
// esttab using "${regression_output}${date}_cso_topics_hyper.csv", se star(* .1 ** .05 *** .01) nogaps label b(3) se(3) long append
// eststo clear





import delimited "output/topics_for_regression_by_year.csv", clear

bysort agency year: egen tot_pubs = sum(pubs)
gen share = pubs/tot_pubs
replace share = 0 if share == .
replace share = 100*share

egen rcdc_id =  group(rcdc), label
egen agency_id =  group(agency), label

eststo clear
capture log close
log using "${regression_output}${date}_cso_topics_by_year.log", replace
foreach cso_code in 1 2 3 4 5 6{
	preserve
		keep if cso == `cso_code'
		eststo: regress share i.year i.agency_id i.rcdc_id, robust
	restore	
}
capture log close
esttab using "${regression_output}${date}_cso_topics_by_year.csv", se star(* .1 ** .05 *** .01) nogaps label b(3) se(3) long append
eststo clear
