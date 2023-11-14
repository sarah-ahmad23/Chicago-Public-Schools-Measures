global Box "C:\Users\saraha6\Box\Attendance-behavioral-academic outcomes"

local date_string = subinstr(c(current_date), " ", "", .)
log using "$Box\Attendance-behavioral-academic_analyses_`date_string'.log", text replace name(main)

set varabbrev off
set more off
set linesize 240
clear all
scalar Box = "$Box"
macro drop _all
global Box = scalar(Box)


****************************************************************************
/*

Note: 

The following code reads and cleans data sets on attendance, misconducts,
freshmen on track (a measure that looks at what percent of high school freshmen
are academically on track for high school) from the Chicago Public Schools. 

Each section cleans the file, performs checks, and runs summary statistics.

Finally, all three datasets are merged with a data on Healthy CPS measurements, 
a variable that relates to measurement from a wellness initiative called Healthy CPS.
Some examples of variables in that include the amount of time students spend outside
or food items available in a cafeteria.

A difference in difference regression is run comparing outcomes from schools that
are in Network 5 and received badges for achieving certain health and wellness
initiatives. The model analyzed variables related to attendance and misconduct.
Analysis couldn't be done because information on Freshmen on Track data was not
available for schools in Network 5. 

The DID model identifies the baseline as the academic year from 2018 to 2019 
and the post year as 2021 to 2022 to identify changes before and after the pandemic.

*/

******************************* ATTENDANCE *********************************
*READ EXCEL FILE
import excel "$Box\Raw Datasets\metrics_attendance_2022.xlsx", sheet("Overtime") firstrow clear

*RENAME VARIABLES
local i = 2003 
foreach v of varlist F-V {
	ren `v' attend`i'
	local i = `i' + 1
}
ren W attend2021
ren X attend2022

*VARIABLE LABELS
label variable SchoolID "CPS School ID"
label variable SchoolName "CPS School Name"
label variable Network "CPS Network"
label variable Group "Whether attendance refers to the whole school or a grade level"
label variable Grade "Grade level" 
foreach v of varlist attend* {
	assert length("`v'") == length("attend")+4
	local year = substr("`v'", -4, .)
	assert `year' >= 2000
	local endyear = string(`year'-2000, "%02.0f")
	assert "`: variable label `v''" == "`year'"
	lab var `v' "Attendance rate, SY`=`year'-1'-`endyear'"
}

*DROP 
li if SchoolName == "CITYWIDE"
drop if SchoolName == "CITYWIDE"
tablist Group Grade, sort(v)
keep if Group == "All (Excludes Pre-K)"
assert Grade == ""
drop Group Grade Network

*DESCRIBE
des2, varwidth(32)

*MISSING
mdesc
assert !mi(SchoolID, SchoolName)

*CHECKS
isid SchoolID
foreach v of varlist attend* {
	assert inrange(`v', 0, 100) if !mi(`v')
}

*SUMMARY STATISTICS
su

*SAVE FILE
local date_string = subinstr(c(current_date), " ", "", .)
save "$Box\Attendance_`date_string'.dta", replace



******************************* MISCONDUCT *********************************
*READ EXCEL FILE
import excel "$Box\Raw Datasets\misconduct_report_police_and_expulsion_thru_eoy_2022_school_level.xlsx", sheet("School Level Behavior Data") firstrow clear

*RENAME VARIABLES
rename (ofMisconducts-Expulsionsper100Students) (Misc Group1_2Misc Group3_4Misc Group5_6Misc Susp PercMiscSusp ISS PercMiscISS ISS100 UniqueStuISS PercUniqueStuISS AvgLengthISS OSS PercMiscOSS OSS100 UniqueStuOSS PercUniqueStuOSS AvgLengthOSS PolNotif PercMiscPol PolNotif100 UniqueStuPol PercUniqueStuPol StuExpel Expul100)

*DROP
tablist * if SchoolName == "", sort(v)
drop if SchoolName == ""
assert inlist(TimePeriod, "S1", "EOY")
keep if TimePeriod == "EOY"
drop TimePeriod

*RECODE
destring SchoolID, replace
clonevar SchoolYear_old = SchoolYear
replace SchoolYear = substr(SchoolYear, -4, .)
destring SchoolYear, replace
tablist SchoolYear SchoolYear_old, sort(v)
drop SchoolYear_old

*DESCRIBE
des2, varwidth(32)

*MISSING
foreach v of varlist Misc-PercUniqueStuPol {
	assert `v' != "" & `v' != "."
	replace `v' = "." if `v' == "--"
	destring `v', replace
}

tab SchoolNetwork, m
mdesc if SchoolNetwork == "Charter"
mdesc if SchoolNetwork != "Charter", any
assert r(miss) == 0

drop SchoolNetwork

*CHECKS
isid SchoolID SchoolYear
assert Misc == Group1_2Misc + Group3_4Misc + Group5_6Misc if !mi(Misc, Group1_2Misc, Group3_4Misc, Group5_6Misc)
assert Susp == ISS + OSS if !mi(Susp, ISS, OSS)
assert abs(PercMiscSusp - round(Susp/Misc*100, 0.1)) < .1 | (PercMiscSusp == 0 & Susp == 0 & Misc == 0) if !mi(PercMiscSusp, Susp, Misc)
assert abs(PercMiscISS - round(ISS/Misc*100, 0.1)) < .1 | (PercMiscISS == 0 & ISS == 0 & Misc == 0) if !mi(PercMiscISS, ISS, Misc)
assert UniqueStuISS <= ISS if !mi(UniqueStuISS, ISS)
assert inrange(AvgLengthISS, 0, 5) if !mi(AvgLengthISS)
assert abs(PercMiscOSS - round(OSS/Misc*100, 0.1)) < .1 | (PercMiscOSS == 0 & OSS == 0 & Misc == 0) if !mi(PercMiscOSS, OSS, Misc)
assert UniqueStuOSS <= OSS if !mi(UniqueStuOSS, OSS)
assert inrange(AvgLengthOSS, 0, 10) if !mi(AvgLengthOSS)
assert UniqueStuPol <= PolNotif if !mi(UniqueStuPol, PolNotif)
assert Expul100 <= 100 if !mi(Expul100)
foreach v of varlist PercUniqueStuISS PercUniqueStuOSS PercUniqueStuPol {
	capture noisily assert inrange(`v', 0, 100) if !mi(`v')
	if _rc tablist `v' if !mi(`v') & !inrange(`v', 0, 100), sort(v)
}

*SUMMARY STATISTICS
distinct SchoolID
su
tab SchoolYear, m

*SAVE FILE
local date_string = subinstr(c(current_date), " ", "", .)
save "$Box\Misconduct_`date_string'.dta", replace

*RESHAPE
drop SchoolName

local varlist
foreach v of varlist * {
	if inlist("`v'", "SchoolID", "SchoolYear") continue
	ren `v' `v'_
	local varlist `varlist' `v'_
	local l`v'_: variable label `v'_
}

reshape wide `varlist', i(SchoolID) j(SchoolYear)

foreach v in `varlist' {
	forvalues y=2014(1)2022 {
		lab var `v'`y' "`l`v'', SY`=`y'-1'-`=`y'-2000'"
	}
}

des2, varwidth(32)

local date_string = subinstr(c(current_date), " ", "", .)
save "$Box\Misconduct_Reshaped_`date_string'.dta", replace

***************************** Freshmen on Track ********************************
*READ EXCEL FILE
import excel "$Box\Raw Datasets\metrics_fot_schoollevel_2022-1.xlsx", sheet("FOT - School Level") clear

*DROP
li in 1/2
drop in 1/2

*RENAME VARIABLES
rename (A-P) (SchoolID SchoolName OnTrackRate_2022 TotalFreshmen_2022 OnTrackRate_2021 TotalFreshmen_2021 OnTrackRate_2019 TotalFreshmen_2019 OnTrackRate_2018 TotalFreshmen_2018 OnTrackRate_2017 TotalFreshmen_2017 OnTrackRate_2016 TotalFreshmen_2016 OnTrackRate_2015 TotalFreshmen_2015)

*VARIABLE LABELS
label variable SchoolID "CPS School ID"
label variable SchoolName "CPS School Name"

foreach var of varlist OnTrackRate_* {
    local y = substr("`var'",-4,.) 
    label variable `var' "% first-time ninth graders who met Freshman On-Track criteria in SY`=`y'-1'-`=`y'-2000'"
}

foreach var of varlist TotalFreshmen_* {
    local y = substr("`var'",-4,.) 
    label variable `var' "# first-time ninth graders eligible for FOT Status in SY`=`y'-1'-`=`y'-2000'"
}

*DESCRIBE
des2, varwidth(32)

*DATA TYPES
destring SchoolID OnTrackRate_2022-TotalFreshmen_2015, replace

*CHECKS
isid SchoolID
mdesc
foreach var of varlist OnTrackRate_* {
    assert `var' <= 100 & `var' >= 0 if !mi(`var')
}

*SUMMARY STATISTICS
su

*SAVE FILE
local date_string = subinstr(c(current_date), " ", "", .)
save "$Box\FOT_`date_string'.dta", replace

******************************* Merging *********************************
use "$Box\Raw Datasets\HealthyCPS_SY2223_NonSvyData_28Jul2023.dta", clear
ren schoolid SchoolID

//Merge with attendance dataset
local date_string = subinstr(c(current_date), " ", "", .)
merge 1:1 SchoolID using "$Box\Attendance_`date_string'.dta", ///
	keepusing(SchoolName attend2003 attend2004 attend2005 attend2006 attend2007 attend2008 attend2009 attend2010 attend2011 ///
	attend2012 attend2013 attend2014 attend2015 attend2016 attend2017 attend2018 attend2019 attend2021 attend2022)
drop if _merge == 2
drop SchoolName _merge

//Merge with Freshmen On Track dataset
local date_string = subinstr(c(current_date), " ", "", .)
merge 1:1 SchoolID using "$Box\FOT_`date_string'.dta", ///
	keepusing(SchoolName OnTrackRate_2022 TotalFreshmen_2022 OnTrackRate_2021 TotalFreshmen_2021 OnTrackRate_2019 TotalFreshmen_2019 ///
	OnTrackRate_2018 TotalFreshmen_2018 OnTrackRate_2017 TotalFreshmen_2017 OnTrackRate_2016 TotalFreshmen_2016 OnTrackRate_2015 TotalFreshmen_2015)
drop if _merge == 2
tab network if _merge == 3, m // can't run DID because no FOT data in networks of interest
drop SchoolName _merge

//Merge with Misconduct dataset
local date_string = subinstr(c(current_date), " ", "", .)
merge 1:1 SchoolID using "$Box\Misconduct_Reshaped_`date_string'.dta", ///
	keepusing(Misc_2014 Group1_2Misc_2014 Group3_4Misc_2014 Group5_6Misc_2014 Susp_2014 PercMiscSusp_2014 ISS_2014 PercMiscISS_2014 ISS100_2014 UniqueStuISS_2014 PercUniqueStuISS_2014 AvgLengthISS_2014 OSS_2014 PercMiscOSS_2014 OSS100_2014 UniqueStuOSS_2014 PercUniqueStuOSS_2014 AvgLengthOSS_2014 PolNotif_2014 PercMiscPol_2014 PolNotif100_2014 UniqueStuPol_2014 PercUniqueStuPol_2014 StuExpel_2014 Expul100_2014 Misc_2015 Group1_2Misc_2015 Group3_4Misc_2015 Group5_6Misc_2015 Susp_2015 PercMiscSusp_2015 ISS_2015 PercMiscISS_2015 ISS100_2015 UniqueStuISS_2015 PercUniqueStuISS_2015 AvgLengthISS_2015 OSS_2015 PercMiscOSS_2015 OSS100_2015 UniqueStuOSS_2015 PercUniqueStuOSS_2015 AvgLengthOSS_2015 PolNotif_2015 PercMiscPol_2015 PolNotif100_2015 UniqueStuPol_2015 PercUniqueStuPol_2015 StuExpel_2015 Expul100_2015 Misc_2016 Group1_2Misc_2016 Group3_4Misc_2016 Group5_6Misc_2016 Susp_2016 PercMiscSusp_2016 ISS_2016 PercMiscISS_2016 ISS100_2016 UniqueStuISS_2016 PercUniqueStuISS_2016 AvgLengthISS_2016 OSS_2016 PercMiscOSS_2016 OSS100_2016 UniqueStuOSS_2016 PercUniqueStuOSS_2016 AvgLengthOSS_2016 PolNotif_2016 PercMiscPol_2016 PolNotif100_2016 UniqueStuPol_2016 PercUniqueStuPol_2016 StuExpel_2016 Expul100_2016 Misc_2017 Group1_2Misc_2017 Group3_4Misc_2017 Group5_6Misc_2017 Susp_2017 PercMiscSusp_2017 ISS_2017 PercMiscISS_2017 ISS100_2017 UniqueStuISS_2017 PercUniqueStuISS_2017 AvgLengthISS_2017 OSS_2017 PercMiscOSS_2017 OSS100_2017 UniqueStuOSS_2017 PercUniqueStuOSS_2017 AvgLengthOSS_2017 PolNotif_2017 PercMiscPol_2017 PolNotif100_2017 UniqueStuPol_2017 PercUniqueStuPol_2017 StuExpel_2017 Expul100_2017 Misc_2018 Group1_2Misc_2018 Group3_4Misc_2018 Group5_6Misc_2018 Susp_2018 PercMiscSusp_2018 ISS_2018 PercMiscISS_2018 ISS100_2018 UniqueStuISS_2018 PercUniqueStuISS_2018 AvgLengthISS_2018 OSS_2018 PercMiscOSS_2018 OSS100_2018 UniqueStuOSS_2018 PercUniqueStuOSS_2018 AvgLengthOSS_2018 PolNotif_2018 PercMiscPol_2018 PolNotif100_2018 UniqueStuPol_2018 PercUniqueStuPol_2018 StuExpel_2018 Expul100_2018 Misc_2019 Group1_2Misc_2019 Group3_4Misc_2019 Group5_6Misc_2019 Susp_2019 PercMiscSusp_2019 ISS_2019 PercMiscISS_2019 ISS100_2019 UniqueStuISS_2019 PercUniqueStuISS_2019 AvgLengthISS_2019 OSS_2019 PercMiscOSS_2019 OSS100_2019 UniqueStuOSS_2019 PercUniqueStuOSS_2019 AvgLengthOSS_2019 PolNotif_2019 PercMiscPol_2019 PolNotif100_2019 UniqueStuPol_2019 PercUniqueStuPol_2019 StuExpel_2019 Expul100_2019 Misc_2020 Group1_2Misc_2020 Group3_4Misc_2020 Group5_6Misc_2020 Susp_2020 PercMiscSusp_2020 ISS_2020 PercMiscISS_2020 ISS100_2020 UniqueStuISS_2020 PercUniqueStuISS_2020 AvgLengthISS_2020 OSS_2020 PercMiscOSS_2020 OSS100_2020 UniqueStuOSS_2020 PercUniqueStuOSS_2020 AvgLengthOSS_2020 PolNotif_2020 PercMiscPol_2020 PolNotif100_2020 UniqueStuPol_2020 PercUniqueStuPol_2020 StuExpel_2020 Expul100_2020 Misc_2021 Group1_2Misc_2021 Group3_4Misc_2021 Group5_6Misc_2021 Susp_2021 PercMiscSusp_2021 ISS_2021 PercMiscISS_2021 ISS100_2021 UniqueStuISS_2021 PercUniqueStuISS_2021 AvgLengthISS_2021 OSS_2021 PercMiscOSS_2021 OSS100_2021 UniqueStuOSS_2021 PercUniqueStuOSS_2021 AvgLengthOSS_2021 PolNotif_2021 PercMiscPol_2021 PolNotif100_2021 UniqueStuPol_2021 PercUniqueStuPol_2021 StuExpel_2021 Expul100_2021 Misc_2022 Group1_2Misc_2022 Group3_4Misc_2022 Group5_6Misc_2022 Susp_2022 PercMiscSusp_2022 ISS_2022 PercMiscISS_2022 ISS100_2022 UniqueStuISS_2022 PercUniqueStuISS_2022 AvgLengthISS_2022 OSS_2022 PercMiscOSS_2022 OSS100_2022 UniqueStuOSS_2022 PercUniqueStuOSS_2022 AvgLengthOSS_2022 PolNotif_2022 PercMiscPol_2022 PolNotif100_2022 UniqueStuPol_2022 PercUniqueStuPol_2022 StuExpel_2022 Expul100_2022)
*
drop if _merge == 2
drop _merge

local date_string = subinstr(c(current_date), " ", "", .)
save "$Box\Attendance-behavioral-academic_analytical_`date_string'.dta", replace

****************************** DID - Attendance ********************************
preserve
keep schoolid attend2019 attend2022 network ncmp_5vs3 ncmp_5vsfu ncmp_5vselem
des2, varwidth(32)

reshape long attend, i(schoolid) j(schoolyear)

gen post = (schoolyear == 2022)
lab def post 0 "Baseline: SY2018-19" 1 "Post: SY2021-22"
lab val post post
tablist post schoolyear, sort(v)

drop if mi(attend)
bysort schoolid: keep if _N == 2

// CHANGE WITHIN NETWORK 5
regress attend i.post if network == "5", vce(cluster schoolid)
// NETWORK 5 VS 3
regress attend i.ncmp_5vs3##i.post, vce(cluster schoolid)
tab ncmp_5vs3 if e(sample), m
// NETWORK 5 VS 8 COMPARISON NETWORKS
regress attend i.ncmp_5vsfu##i.post, vce(cluster schoolid)
tab ncmp_5vsfu if e(sample), m
// NETWORK 5 VS OTHER ELEMENTARY NETWORKS
regress attend i.ncmp_5vselem##i.post, vce(cluster schoolid)
tab ncmp_5vselem if e(sample), m
restore

****************************** DID - Misconduct ********************************
preserve
keep schoolid ISS100_2019 ISS100_2022 OSS100_2019 OSS100_2022 network ncmp_5vs3 ncmp_5vsfu ncmp_5vselem
des2, varwidth(32)

reshape long ISS100_ OSS100_, i(schoolid) j(schoolyear)
ren ISS100_ ISS100
ren OSS100_ OSS100

gen post = (schoolyear == 2022)
lab def post 0 "Baseline: SY2018-19" 1 "Post: SY2021-22"
lab val post post
tablist post schoolyear, sort(v)

assert (mi(ISS100) & mi(OSS100)) | (!mi(ISS100) & !mi(OSS100))
drop if mi(ISS100)
bysort schoolid: keep if _N == 2

// CHANGE WITHIN NETWORK 5
regress ISS100 i.post if network == "5", vce(cluster schoolid)
regress OSS100 i.post if network == "5", vce(cluster schoolid)
// NETWORK 5 VS 3
regress ISS100 i.ncmp_5vs3##i.post, vce(cluster schoolid)
regress OSS100 i.ncmp_5vs3##i.post, vce(cluster schoolid)
tab ncmp_5vs3 if e(sample), m
// NETWORK 5 VS 8 COMPARISON NETWORKS
regress ISS100 i.ncmp_5vsfu##i.post, vce(cluster schoolid)
regress OSS100 i.ncmp_5vsfu##i.post, vce(cluster schoolid)
tab ncmp_5vsfu if e(sample), m
// NETWORK 5 VS OTHER ELEMENTARY NETWORKS
regress ISS100 i.ncmp_5vselem##i.post, vce(cluster schoolid)
regress OSS100 i.ncmp_5vselem##i.post, vce(cluster schoolid)
tab ncmp_5vselem if e(sample), m
restore

log close _all
