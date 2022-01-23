# Nginx-Fun
This is a playground project for website fullstack development using containerization and CI/CD. The original idea come from my dissatisfaction with AirBank Graphing tool. It would probably be easy to find an existing graphing tool (might do that later for inspiration), but this way, it'll be an educational experience.

## The goal
I aim to create a simple webserver, which would take data, process and store it in a database, and finally present the data from database via a set of graphs.
### The data
The data will be CSV files containing my bank account transactions. Only data format exported from AirBank will be supported.
### The processing
Data should be loaded from CSV files and used to populate a relational database. Only one file will be processed at a time. 
### Data visualization
Final graphs should be able to:
*  Display total income vs total expenditure on monthly basis
*  Display expenditures by category, expenditure details should be just one click away
