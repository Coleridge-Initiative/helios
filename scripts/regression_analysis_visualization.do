// ssc install egenmore

set matsize 11000

cd "/Users/nj995/dropbox/projects/2018_helios/"

global date "20181121"
global figure_output "output/trend_figures/"

import delimited "data/regression_dataset.csv", clear


************************************
************************************
* DATA CLEANUP:
************************************
************************************

* TEMP:
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

* Keep only first grant for every researcher:
sort rsr_id start_date grant_id year
duplicates drop rsr_id time_pos, force

* Keep only is there is an affiliation
drop if rsr_affiliation == ""

* Create Funder Category, Person Category, Researcher Country, Researcher Affiliation
egen funder_id = group(funder_name), label
egen person_id = group(rsr_id)
egen rsr_country_id = group(rsr_country), label
egen rsr_affiliation_id = group(rsr_affiliation)
egen orcid_confirmed_rsr = group(orcid_confirmed), label
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
gen citations_per_year = citations_per_pub/years_since_pub


************************************
************************************
* REGRESSIONS:
************************************
************************************

/*
1 Cancer Research UK
2 INCa/INSERM/DGOS
3 National Cancer Institute
4 National Health and Medical Rese
5 Wellcome Trust
*/

drop funder_id
gen funder_id=1 if funder_name=="Cancer Research UK"
replace funder_id=2 if funder_name=="INCa/INSERM/DGOS"
replace funder_id=3 if funder_name=="National Cancer Institute"
replace funder_id=4 if funder_name=="National Health and Medical Research Council"
replace funder_id=5 if funder_name=="Wellcome Trust"

decode pre_post_year, gen(period_temp)

gen period_6=(period_temp=="pre_0")
forvalues i=2/5{
	local j=`i'-6
	gen period_`i'=(period_temp=="pre_`j'")
}
forvalues i=1/5{
	local j=`i'+6
	gen period_`j'=(period_temp=="post_`i'")
}

tab funder_id, gen(funder_id_)
drop pre_post_year period_temp funder_id_1

forvalues i=2/11{
	forvalues j=2/5{
		gen int_period_`i'_x_funder_`j'=(period_`i'==1&funder_id_`j')
	}
}


local name_nb_pubs "Number of Publications"
local name_nb_collabs "Number of Unique Collabs"
local name_nb_collab_countries "Breadth (#Countries) of Collabs"
local name_citations_per_pub "Citations per Publication"
local name_citations_per_year "Citations per Publication per Year"

local yname_nb_pubs "Publications"
local yname_nb_collabs "Collaborations"
local yname_nb_collab_countries "Collaborations"
local yname_citations_per_pub "Citations"
local yname_citations_per_year "Citations per Year"

local nb_pubs_range_min 2
local nb_pubs_range_max 10
local nb_collabs_range_min 0 
local nb_collabs_range_max 80
local nb_collab_countries_range_min 1
local nb_collab_countries_range_max 5
local citations_per_pub_range_min 0
local citations_per_pub_range_max 80
local citations_per_year_range_min 2
local citations_per_year_range_max 10

local grant_controls funding_len funding_amount nb_rsrs
local dependant_vars nb_pubs nb_collabs nb_collab_countries citations_per_pub citations_per_year

local weight_vars 1 weight

local 1_suffix "without_weights"
local weight_suffix "propensity_weights"

foreach weight_var in `weight_vars'{

	foreach depvar in `dependant_vars'{	

		xtset person_id
		xtreg `depvar' period_* int_* [aweight=`weight_var'], fe robust
		predict fixed, u
		preserve
			keep person_id fixed funder_id
			duplicates drop
			
			forvalues j=1/5{
				sum fixed if funder_id==`j'
				local be_fixed_`j'=r(mean)
			}
		restore
		
		
		forvalues j=1/5{
			local be_p_1_f_`j'=_b[_cons] + `be_fixed_`j''
			local mx_p_1_f_`j'=(_b[_cons]+1.96*_se[_cons]) + `be_fixed_`j''
			local mn_p_1_f_`j'=(_b[_cons]-1.96*_se[_cons]) + `be_fixed_`j''
			forvalues i=2/11{
				local be_base_p_`i'_f_`j'=_b[_cons] + `be_fixed_`j'' + _b[period_`i']
				local mx_base_p_`i'_f_`j'=(_b[_cons]+1.96*_se[_cons]) + `be_fixed_`j'' + (_b[period_`i']+1.96*_se[period_`i'])
				local mn_base_p_`i'_f_`j'=(_b[_cons]-1.96*_se[_cons]) + `be_fixed_`j'' + (_b[period_`i']-1.96*_se[period_`i'])
			}
		}
		forvalues i=2/11{
			local be_p_`i'_f_1=`be_base_p_`i'_f_1'
			local mx_p_`i'_f_1=`mx_base_p_`i'_f_1'
			local mn_p_`i'_f_1=`mn_base_p_`i'_f_1'
			forvalues j=2/5{
				local be_p_`i'_f_`j'=`be_base_p_`i'_f_`j'' + _b[int_period_`i'_x_funder_`j']
				local mx_p_`i'_f_`j'=`mx_base_p_`i'_f_`j'' + (_b[int_period_`i'_x_funder_`j']+1.96*_se[int_period_`i'_x_funder_`j'])
				local mn_p_`i'_f_`j'=`mn_base_p_`i'_f_`j'' + (_b[int_period_`i'_x_funder_`j']-1.96*_se[int_period_`i'_x_funder_`j'])
			}
		}
			
		preserve
			clear
			set obs 11
			gen period=_n
			expand 5
			bysort period: gen funder=_n
				
			foreach type in be mx mn{
				gen `type'_`depvar'=.
				forvalues i=1/11{
					forvalues j=1/5{
						replace `type'_`depvar'=``type'_p_`i'_f_`j'' if period==`i'&funder==`j'
						replace `type'_`depvar'=``depvar'_range_max' if `type'_`depvar'>``depvar'_range_max'
						replace `type'_`depvar'=``depvar'_range_min' if `type'_`depvar'<``depvar'_range_min'
					}
				}
			}
			
			reshape wide be_`depvar' mx_`depvar' mn_`depvar', i(period) j(funder)
			
			
			label define Periods_Num 1 "-5" 2 "-4" 3 "-3" 4 "-2" 5 "-1" 6 "0" 7 "+1" 8 "+2" 9 "+3" 10 "+4" 11 "+5"
			label values period Periods_Num
		
			twoway rarea mn_`depvar'1 mx_`depvar'1 period, color(red%3) || ///
			rarea mn_`depvar'2 mx_`depvar'2 period, color(midgreen%3) || ///
			rarea mn_`depvar'3 mx_`depvar'3 period, color(midblue%3) || ///
			rarea mn_`depvar'4 mx_`depvar'4 period, color(purple%3) || ///
			rarea mn_`depvar'5 mx_`depvar'5 period, color(gold%3) || ///
			line be_`depvar'* period, title(`name_`depvar'') ///
			xtitle(" " "Years from First Grant") xlabel(1(1)11, valuelabels) ///
			ytitle("`yname_`depvar''" " ") ysc(r(``depvar'_range_min' ``depvar'_range_max')) ///
			lpattern(longdash solid longdash longdash longdash) ///
			lwidth(medthick medthick medthick medthick medthick) ///
			lcolor(red%50 midgreen%90 midblue%50 purple%50 gold%50) ///
			title(`name_`depvar'') ///
			note("Notes: Sample includes 132,913 observations within +/- 5 years of the first grant received" /// 
			"by 12,083 researchers. The figure plots predicted values from a linear regression of scientific" ///
			"output on indicator variables for the years surrounding the grant, individual fixed-effects," ///
			"and an interaction between funding agency and years surrounding the grant." ///
			"Colored bands represent a 95% CI around the point estimate.", size(vsmall)) ///
			legend(order(6 "Cancer Research UK" 7 "INCa/INSERM/DGOS" 8 "NCI" 9 "NHMRC" 10 "Welcome")) ///
			saving("${figure_output}${date}_`depvar'_figure_``weight_var'_suffix'.gph", replace)
			graph export "${figure_output}${date}_`depvar'_figure_``weight_var'_suffix'.png", replace
		restore	
		drop fixed
	}
}

