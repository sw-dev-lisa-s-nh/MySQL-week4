
--
-- MySQL Week 4 Coding Assignment
-- Promineo Tech BESD Coding Bootcamp
--

USE employees;

--
-- Coding Assignment #4 
-- Requirements:  
--		1.  Write 5 stored procedures for the employees database.
-- 		2.  Write a description of what each stored procedure does and how to use it.
-- NOTE:  Procedures should use constructs you learned about from your 
--			research assignment and be more than just queries.
--
--
-- MySQL Week 4 Coding Assignment
-- Procedure #1
-- Get the count of the employees in a particular department.
-- Input parameter:  department_name
-- Output Parameter:  num_of_emp

DROP PROCEDURE IF EXISTS GetEmpCountByDept; 

DELIMITER %% ;
CREATE PROCEDURE GetEmpCountByDept (IN department_name VARCHAR(40), INOUT num_of_emp INTEGER)
BEGIN	
	-- Check that department_name actually exists
	SELECT count(*) 
	INTO num_of_emp  	
	FROM departments d
	WHERE d.dept_name = department_name;	
	-- If it exists in the departments table, then do a count
	-- Otherwise, just return.
	IF (num_of_emp = 1)
	THEN
		SELECT count(*) INTO num_of_emp 
		FROM employees e
		INNER JOIN dept_emp de USING (emp_no)
		INNER JOIN departments d USING (dept_no)
		GROUP BY d.dept_name HAVING d.dept_name = department_name;	
	ELSE
		SET num_of_emp = 0;	
	END IF; 	
END%%
	
DELIMITER ; %%



-- Procedure #2  CalculateRaise()
-- Calculate Raise based on current salary
-- 	 Input parametesr:  emp_num, percentageRaise, 
-- 	 Output Parameter: newSalary

DROP PROCEDURE IF EXISTS CalculateRaise; 

DELIMITER %% ;

CREATE PROCEDURE CalculateRaise (IN emp_num INT, IN percentRaise INT, OUT newSalary INT) 
BEGIN
	DECLARE currentSalary DECIMAL(10,2);
	
	SELECT max(salary)
	INTO currentSalary 
	FROM salaries
	WHERE emp_no = emp_num;
	
	SET newSalary = currentSalary + (currentSalary*(percentRaise/100));
END %%
		
DELIMITER ; %%



-- Procedure #3:  AddNewEmployee()
--  
--  Add an employee to the employees database.  
--   (1) Auto-increment the employee number, to avoid duplicates.  
--		 Retrieve the max emp_no value, and increment when inserting the new employee.
--   (2) Insert record into employees table with new_emp_no variable & input params.
--   (3) Insert record into dept_emp table with new_emp_no & dept_num input params.
--   (4) 
-- 
-- 	 Input parameter:  birth_date, first_name, last_name, gender, hire_date, dept_num,
--					   salary, title,
-- 	 Output Parameter:  none
--   Local Variables:  max_emp_no -- the current maximum employee number
--                     new_emp_no -- max_emp_no incremented by one
--					   def_to_date -- set to "9999-01-01"
--					   def_from_date -- set to CURDATE()
--


DROP PROCEDURE IF EXISTS AddNewEmployee;

DELIMITER %% ;

CREATE PROCEDURE AddNewEmployee(IN birthdate DATE,
							  IN f_name VARCHAR(14),
							  IN l_name VARCHAR(16),
							  IN gender_val ENUM('M','F'),
							  IN hiredate DATE,
							  IN dept_num CHAR(4),
							  IN new_salary INTEGER,
							  IN new_title VARCHAR(50),
							  OUT error BOOLEAN)
BEGIN		
	DECLARE emp_equal_count INT DEFAULT 0;
	DECLARE max_emp_no,new_emp_no INTEGER DEFAULT 0;
	DECLARE def_to_date DATE DEFAULT "9999-01-01";
	DECLARE def_from_date DATE DEFAULT CURDATE();
	SELECT max(emp_no) INTO max_emp_no FROM employees;
	SET new_emp_no = max_emp_no + 1;
	SET error = 0;
	
	SELECT count(*) 
	INTO emp_equal_count 
	FROM employees
	WHERE birth_date = birthdate AND first_name = f_name AND last_name = l_name;
	
	IF emp_equal_count = 0
	THEN
		INSERT INTO employees (emp_no, birth_date, first_name,last_name,gender,hire_date)
			VALUES (new_emp_no, birthdate, f_name, l_name, gender_val, hiredate);
		INSERT INTO salaries (emp_no, from_date, salary, to_date)
			VALUES (new_emp_no, def_from_date, new_salary, def_to_date);
		INSERT INTO titles (emp_no, title, from_date, to_date)
			VALUES (new_emp_no, new_title, def_from_date, def_to_date); 	
		INSERT INTO dept_emp (emp_no,dept_no,from_date,to_date)
			VALUES (new_emp_no,dept_num,def_from_date,def_to_date);	
		SET ERROR = 1;
	ELSE
		SET ERROR = 0;
	END IF;	
END%%   
	
DELIMITER ; %%
	


-- Procedure #4:  SalaryPerCalendarYear()
--				  This procedure calculates the calendar year salary total 
--				  for a particular employee in a particular department.
-- 
-- 	 Input parameter:  emp_no, cal_year, department_name
-- 	 Output Parameter:  pro_rated_salary
--



-- In the salary table, there is one record per year, per salary, per employee.
-- In the dept_emp, we can correlate which employees worked for which department
-- within a calendar year.
--
-- Since there is a record per year, per salary, per employee, in the salaries table
-- then the salary changes on the from_date to a new salary.  

-- Salary in the employees database has a value which is in effect for one year,
-- 		starting at a random date in the year.  
--		(e.g.  53000 salary from 1989-05-06 to 1990-05-05
--		  AND  54500 salary from 1990-05-06 to 1991-05-05)
-- 		What if an employer wants to know calendar year pro-rating, or possibly
--		fiscal year pro-rating?  This procedure returns the calendar year pro-rating.


DROP PROCEDURE IF EXISTS SalaryPerCalendarYear; 

DELIMITER %% ;

CREATE PROCEDURE SalaryPerCalendarYear (IN emp_no INT, 
										   IN cal_year INT, 
										   IN department_name VARCHAR(40),
										   OUT pro_rated_salary DECIMAL(11,2))
READS SQL DATA
BEGIN
	DECLARE variable1 DECIMAL(11,2) DEFAULT 0.00;
	DECLARE variable2 DECIMAL(11,2) DEFAULT 0.00;
	SET pro_rated_salary = 0.00;
	
	-- Query 1:  Returns the first record -- for the first part of the salary year
	-- 			 (FROM from_date to 12/31)
	SELECT IF ((EXTRACT(YEAR FROM s.from_date) = cal_year), 
				(((s.salary/ DATEDIFF(s.to_date, s.from_date))* 
				(DATEDIFF(s.to_date, s.from_date)- DAYOFYEAR(s.from_date)))), 0)				  
	INTO variable1
	FROM salaries s 
	INNER JOIN dept_emp de ON (de.emp_no = s.emp_no) 
	INNER JOIN departments d ON (d.dept_no = de.dept_no AND d.dept_name = department_name AND (s.from_date BETWEEN de.from_date AND de.to_date)) 
	WHERE s.emp_no = emp_no AND (EXTRACT(YEAR FROM s.from_date) = 1990);	


	-- Query 2:  Returns the second record -- for the second part of the salary year
	-- 			 (1/1 to the to_date)	
	SELECT IF ( (EXTRACT(YEAR FROM s.to_date) = cal_year), 
				(((s.salary/ DATEDIFF(s.to_date, s.from_date))* DAYOFYEAR(s.to_date))), 0)
	INTO variable2
	FROM salaries s 
	INNER JOIN dept_emp de ON (de.emp_no = s.emp_no) 
	INNER JOIN departments d ON (d.dept_no = de.dept_no AND d.dept_name = department_name AND (s.to_date BETWEEN de.from_date AND de.to_date)) 
	WHERE s.emp_no = emp_no AND (EXTRACT(YEAR FROM s.to_date) = 1990);
		
	SET pro_rated_salary = variable1 + variable2;
	
END %%

DELIMITER ; %%


-- Procedure #5:  UpdateEmploymentRecord() 
-- 				Record that an employee changed departments (getting
--				 hired from one department into another department.
--				(1)  to_date in dept_emp with old dept assigned to CURDATE();
--				(2)  add record to dept_emp table with new data: 
--						(a) from_date = CURDATE()
--						(b) to_date = "9999-01-01" 
--						(c) dept_no = new dept 
--						(d) emp_no = emp_no 
-- 	 Input parameter: emp_no, old_dept, new_dept, new_start_date, 
-- 	 Output Parameter:  error -- If 0, nothing happened!
--

DROP PROCEDURE IF EXISTS UpdateEmploymentRecord; 

DELIMITER %% ;
CREATE PROCEDURE UpdateEmploymentRecord(IN emp_num INT, 
										  IN old_dept CHAR(4), 
										  IN new_dept CHAR(4), 
										  IN effective_on DATE, 
										  OUT error INTEGER)
READS SQL DATA
BEGIN
	DECLARE emp_in_old_dept INTEGER DEFAULT 0;

	SELECT count(*) 
	INTO emp_in_old_dept
	FROM dept_emp de
	INNER JOIN departments d ON de.dept_no = d.dept_no 
	WHERE de.emp_no = emp_num;

	IF (emp_in_old_dept > 0)
	THEN 
		UPDATE dept_emp de SET de.to_date = effective_on
		WHERE de.emp_no = emp_num;	
		INSERT INTO dept_emp (emp_no,dept_no,from_date,to_date)
				VALUES (emp_num,new_dept,effective_on,"9999-01-01");	
	ELSE	
		SET emp_in_old_dept = 0;
	END IF;

	SET error = emp_in_old_dept;
		
END %%

DELIMITER ; %%


		