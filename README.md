# Chicago-Public-Schools-Measures

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
