Applications to work with Oracle DB Objects
===========================================

AS-TRANS - Oracle SQL statement Transcriber
-------------------------------------------

Transform Oracle SQL statements to unified and well-documented format:
* [picture 1](as_trans/as_trans_picture_01.png)
* [picture 2](as_trans/as_trans_picture_02.png)

The new SQL statement has: 
* description of all query tables/views
* links to the Oracle documentation
* descrtiption and available values of all columns in the statement
* info about compatibility with different Oracle versions

User can add Title and Hint to the result SQL statement.
User can define the custom format for the outputs (see [util](as_trans/util) directory).

AS-PAR - Hand-Book of Oracle Classified Documented and Classified Un-Documented Parameters
------------------------------------------------------------------------------------------

Includes information about 1391 parameters grouped in 182 classes.
* [picture 1](as_par/as_par_picture_01.png)
* [picture 2](as_par/as_par_picture_02.png)

The common information about Parameters is grouped in the tabs:
- Purpose
- Properties
- Description
- Values
- Warnings
- Comments
- Links to other sources
- See also - link to Oracle docs (per version)

AS-DPV - Hand-Book of Oracle Dynamic Performance Views (DPV)
------------------------------------------------------------

Includes information about 742 objects grouped in 142 classes:
* [picture 1](as_dpv/as_dpv_picture_01.png)
* [picture 2](as_dpv/as_dpv_picture_02.png)

The specific information about all DPV objects: column names; column datatypes; column description with available values.
The common information about DPV objects is grouped in the tabs:
- Purpose
- Description
- Warnings
- Comments
- Build (parent SQL and dependencies)
- Links to other sources
- See also - link to Oracle docs (per version)

AS-SDDV - Hand-Book of Oracle System Data Dictionary Views (SDDV)
-----------------------------------------------------------------
* TBD

All applications have information (and could be filtered) about components of the following Oracle versions:
  - 8.0.5 
  - 8.1.5 
  - 8.1.6 
  - 8.1.7 
  - 9.0.1
  - 9.2.0
  - 10.1.0

Convenient Search system in all applications.
