set matsize 11000

cd "/Users/nj995/dropbox/projects/2018_helios/"

global date "20181116"

import delimited "data/researcher_info.csv", clear
save "data/stata/researcher_info.dta", replace

import delimited "data/funded_grants.csv", clear

* Keep first of every researcher
sort rsr_id start_date
duplicates drop rsr_id, force

merge 1:1 rsr_id using "data/stata/researcher_info.dta" 

gen inca_flag = (funder_name == "INCa/INSERM/DGOS")

foreach var of varlist cso_* rcdc_* {
	replace `var' = 0 if `var'==.
	replace `var' = 1 if `var'>0
}
// foreach var of varlist rsr_nb_early_citations rsr_nb_early_pubs{
// 	replace `var' = 0 if `var'==.
// }

* Restrict to CSO and RCDC codes with at least 100 researchers
local threshold = 500
gen cso_other = 0
foreach var of varlist cso_*{
	sum `var'
 	local test = `r(sum)'
	if `test'<`threshold'{
		replace cso_other = 1 if `var' == 1 
 		drop `var'
	}
}
gen rcdc_other = 0
foreach var of varlist rcdc_*{
	sum `var'
 	local test = `r(sum)'
	if `test'<`threshold'{
		replace rcdc_other = 1 if `var' == 1 
 		drop `var'
	}
}

* Career Age
gen start_year = year(date(start_date, "YMD"))
gen rsr_career_age = start_year - rsr_career_start_year
egen rsr_gender_cat = group(rsr_gender), label

preserve
	keep if funder_name == "INCa/INSERM/DGOS" |  funder_name == "Cancer Research UK"
	pscore inca_flag rsr_career_age rsr_gender_cat rsr_nb_early_pubs rsr_nb_early_citations cso_* rcdc_*, pscore(inca_prob) detail comsup logit
	replace inca_prob=0 if comsup!=1
	sum inca_prob, detail
	replace inca_prob = r(mean)+2*r(sd) if inca_prob>r(mean)+2*r(sd)
	gen weight=inca_prob/(1-inca_prob)
	drop if funder_name == "INCa/INSERM/DGOS"
	keep funder_name rsr_id grant_id inca_prob weight
	save "data/stata/cruk_weight.dta", replace
restore
preserve
	keep if funder_name == "INCa/INSERM/DGOS" |  funder_name == "National Cancer Institute"
	pscore inca_flag rsr_career_age rsr_gender_cat rsr_nb_early_pubs rsr_nb_early_citations cso_* rcdc_*, pscore(inca_prob) detail comsup logit
	replace inca_prob=0 if comsup!=1
	sum inca_prob, detail
	replace inca_prob = r(mean)+2*r(sd) if inca_prob>r(mean)+2*r(sd)
	gen weight=inca_prob/(1-inca_prob)
	drop if funder_name == "INCa/INSERM/DGOS"
	keep funder_name rsr_id grant_id inca_prob weight
	save "data/stata/nci_weight.dta", replace
restore
preserve
	keep if funder_name == "INCa/INSERM/DGOS" |  funder_name == "National Health and Medical Research Council"
	pscore inca_flag rsr_career_age rsr_gender_cat rsr_nb_early_pubs rsr_nb_early_citations cso_* rcdc_*, pscore(inca_prob) detail comsup logit
	replace inca_prob=0 if comsup!=1
	sum inca_prob, detail
	replace inca_prob = r(mean)+2*r(sd) if inca_prob>r(mean)+2*r(sd)
	gen weight=inca_prob/(1-inca_prob)
	drop if funder_name == "INCa/INSERM/DGOS"
	keep funder_name rsr_id grant_id inca_prob weight
	save "data/stata/nhmrc_weight.dta", replace
restore
preserve
	keep if funder_name == "INCa/INSERM/DGOS" |  funder_name == "Wellcome Trust"
	pscore inca_flag rsr_career_age rsr_gender_cat rsr_nb_early_pubs rsr_nb_early_citations cso_* rcdc_*, pscore(inca_prob) detail comsup logit
	replace inca_prob=0 if comsup!=1
	sum inca_prob, detail
	replace inca_prob = r(mean)+2*r(sd) if inca_prob>r(mean)+2*r(sd)
	gen weight=inca_prob/(1-inca_prob)
	drop if funder_name == "INCa/INSERM/DGOS"
	keep funder_name rsr_id grant_id inca_prob weight
	save "data/stata/wt_weight.dta", replace
restore


drop if funder_name!="INCa/INSERM/DGOS"
gen inca_prob = 1
gen weight = 1
keep funder_name rsr_id grant_id inca_prob weight

append using "data/stata/cruk_weight.dta"
append using "data/stata/nci_weight.dta"
append using "data/stata/nhmrc_weight.dta"
append using "data/stata/wt_weight.dta"

export delimited "data/rsr_weights.csv", replace


* try comparing INCa to all others
