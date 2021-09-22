# BambooHR tools

## Setup

Clone and set up the repo:

```
git clone https://github.com/amandavarella/junk.git
cd junk/bamboohr
bundle
```

Add a `.env` with your BambooHR API key:

``` bash
BAMBOOHR_SUBDOMAIN=mycorp
BAMBOOHR_API_KEY=
```
To get your BambooHR API Key, go to your home interface on Bamboo:
* Click on your avatar on the top right side of the screen
* Click on My Devices & API Keys

Scrape the org chart from BambooHR:

1. Go to https://mycorp.bamboohr.com/employees/orgchart.php
1. Click on Export \  `Unformatted.csv`
1. Rename the file to `employees.csv`, and leave it under the  `bamboohr` directory


## Execution

`report_time_off.rb` Generates a report of the days worked by folks under someone in the org chart

### Names in the first column

``` bash
ruby report_time_off.rb --under-user 'Amanda Varella'
```

This command will generate the report in the following format, reporting on the current week
```
date,2021-08-30
Amanda Varella,5
John Smith,4
Jane Lawrence,5
James Stuart,3
```
### Names in the header

``` bash
ruby report_time_off.rb --under-user 'Amanda Varella' -t
```
This command will generate the report in the following format, reporting on the current week
```
date,Amanda Varella Pereira,John Smith,Jane Lawrence,James Stuart
2021-08-30,5,4,5,3
```

### Specifying a week to query:

``` bash
ruby report_time_off.rb --under-user 'Amanda Varella' --start-date 2021-08-30 --weeks 2 <-t>
```
This command will generate the report on the number of weeks specified, starting from the week specified. Add or remove -t, according to your exporting needs (names in the header or names in columns)

without -t
```
date,2021-08-30,2021-09-06
Amanda Varella,5,4
John Smith,4,5
Jane Lawrence,5,5
James Stuart,3,5
```

with -t
```
date,Amanda Varella Pereira,John Smith,Jane Lawrence,James Stuart
2021-08-30,5,4,5,3
2021-09-06,4,5,5,5
```

## Other information

Takes into account public holidays too.

It doesn't take into account part time workers.

For dates in the past, this will report leave taken.

For dates in the future, this will report booked leave.

