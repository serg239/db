Applications to work with Oracle DB Objects
===========================================

AS-TRANS - Oracle SQL statement Transcriber
-------------------------------------------

Transform Oracle SQL statements to unified and well-documented format:
* [picture 1](as_trans/as_trans_picture_01.png) and [example_1](as_trans/as_trans_example_01.txt) 
* [picture 2](as_trans/as_trans_picture_02.png) and [example_2](as_trans/as_trans_example_02.txt) 

The new SQL statement has: 
* description of all system tables and views in the statement
* descrtiption and available values of all columns in the statement
* link(s) to the Oracle documentation about used tables and views
* info about workability of statement in different Oracle versions

User can add Title and Hint to the result SQL statement.

User can define the custom format for the outputs (see [util](as_trans/util) directory) also.

Notes
-----
1. All generated SQL statements have information about tables and fields of the following Oracle versions:
  - [x] 8.0.5 
  - [x] 8.1.5 
  - [x] 8.1.6 
  - [x] 8.1.7 
  - [x] 9.0.1
  - [x] 9.2.0
  - [x] 10.1.0
  - [ ] 11.x - TBD
  - [ ] 12.x - TBD
