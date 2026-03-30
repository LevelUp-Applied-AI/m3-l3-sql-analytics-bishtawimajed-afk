-- Q1
SELECT e.name, d.name AS department_name, e.salary
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
ORDER BY d.name ASC, e.salary DESC;

-- Q2
SELECT d.name, SUM(e.salary) AS total_expenditure
FROM departments d
JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.name
HAVING SUM(e.salary) > 150000;

-- Q3
SELECT name, department_name, salary
FROM (
    SELECT e.name, d.name AS department_name, e.salary,
           ROW_NUMBER() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) as rank
    FROM employees e
    JOIN departments d ON e.dept_id = d.dept_id
) AS ranked_employees
WHERE rank = 1;

-- Q4
SELECT p.name, COUNT(pa.emp_id) AS employee_count, COALESCE(SUM(pa.hours_allocated), 0) AS total_hours
FROM projects p
LEFT JOIN project_assignments pa ON p.project_id = pa.project_id
GROUP BY p.project_id, p.name;

-- Q5
WITH CompanyAvg AS (
    SELECT AVG(salary) as global_avg FROM employees
)
SELECT d.name, AVG(e.salary) AS dept_avg, (SELECT global_avg FROM CompanyAvg) as company_avg
FROM departments d
JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.name
HAVING AVG(e.salary) > (SELECT global_avg FROM CompanyAvg);

-- Q6
SELECT name, salary, 
       SUM(salary) OVER (PARTITION BY dept_id ORDER BY hire_date) AS running_total
FROM employees;

-- Q7
SELECT e.name
FROM employees e
LEFT JOIN project_assignments pa ON e.emp_id = pa.emp_id
WHERE pa.project_id IS NULL;

-- Q8
WITH MonthlyHires AS (
    SELECT DATE_TRUNC('month', hire_date) AS hire_month, COUNT(*) AS count
    FROM employees
    GROUP BY hire_month
)
SELECT hire_month, count
FROM MonthlyHires
ORDER BY hire_month;

-- Q9
CREATE TABLE certifications (
    certification_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    issuing_org VARCHAR(255),
    level VARCHAR(50)
);

CREATE TABLE employee_certifications (
    id SERIAL PRIMARY KEY,
    emp_id INT REFERENCES employees(emp_id),
    certification_id INT REFERENCES certifications(certification_id),
    certification_date DATE NOT NULL
);

INSERT INTO certifications (name, issuing_org, level) VALUES 
('AWS Cloud Practitioner', 'Amazon', 'Beginner'),
('Google Data Analytics', 'Google', 'Intermediate'),
('Professional Engineer', 'IEEE', 'Advanced');

INSERT INTO employee_certifications (emp_id, certification_id, certification_date) VALUES 
(1, 1, '2023-01-15'),
(2, 2, '2023-02-20'),
(3, 3, '2023-03-10'),
(4, 1, '2023-04-05'),
(5, 2, '2023-05-12');

SELECT e.name AS employee_name, c.name AS certification_name, c.issuing_org, ec.certification_date
FROM employees e
JOIN employee_certifications ec ON e.emp_id = ec.emp_id
JOIN certifications c ON ec.certification_id = c.certification_id;

-- Challenge Extensions
-- --------------------------------------------------

-- Tier 1: Complex Analytics Queries

-- 1. Identify "at-risk" projects (> 80% budget used)
SELECT p.name AS project_name, p.budget, SUM(pa.hours_allocated) AS total_hours
FROM projects p
JOIN project_assignments pa ON p.project_id = pa.project_id
GROUP BY p.project_id, p.name, p.budget
HAVING SUM(pa.hours_allocated) > (p.budget * 0.8);

-- 2. Cross-department analysis (Employees in different departments than their projects)
SELECT e.name AS employee_name, d_emp.name AS emp_dept, p.name AS project_name, d_proj.name AS proj_dept
FROM employees e
JOIN departments d_emp ON e.dept_id = d_emp.dept_id
JOIN project_assignments pa ON e.emp_id = pa.emp_id
JOIN projects p ON pa.project_id = p.project_id
JOIN departments d_proj ON p.dept_id = d_proj.dept_id
WHERE e.dept_id <> p.dept_id;

-- Tier 2: Views and Functions
- -  ---------------------------------------

-- 1. Create a Department Summary View
CREATE OR REPLACE VIEW department_summary AS
SELECT d.name, COUNT(e.emp_id) AS employee_count, SUM(e.salary) AS total_salary
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.name;

-- 2. Create a Function for Department Stats
CREATE OR REPLACE FUNCTION get_dept_stats(dept_name_in TEXT)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'employee_count', (SELECT COUNT(*) FROM employees e JOIN departments d ON e.dept_id = d.dept_id WHERE d.name = dept_name_in),
            'total_salary', (SELECT SUM(salary) FROM employees e JOIN departments d ON e.dept_id = d.dept_id WHERE d.name = dept_name_in),
            'active_projects', (SELECT COUNT(*) FROM projects p JOIN departments d ON p.dept_id = d.dept_id WHERE d.name = dept_name_in)
        )
    );
END;
$$ LANGUAGE plpgsql;


-- Tier 3: Schema Evolution and Migration
-- ------------------------------------------------------

-- 1. Create salary_history table
CREATE TABLE IF NOT EXISTS salary_history (
    history_id SERIAL PRIMARY KEY,
    emp_id INT REFERENCES employees(emp_id),
    old_salary DECIMAL(10, 2),
    new_salary DECIMAL(10, 2),
    change_date DATE NOT NULL
);

-- 2. Migration Script: Populate history with current salaries as initial records
INSERT INTO salary_history (emp_id, old_salary, new_salary, change_date)
SELECT emp_id, 0, salary, hire_date
FROM employees;

-- 3. Seeding additional history (Realistic data for past 3 years)
INSERT INTO salary_history (emp_id, old_salary, new_salary, change_date) VALUES
(1, 55000, 60000, '2024-01-15'),
(2, 48000, 52000, '2023-11-20'),
(3, 70000, 75000, '2025-02-01');

-- 4. Analytics: Salary growth rate by department
SELECT d.name AS department, 
       ROUND(AVG((sh.new_salary - sh.old_salary) / NULLIF(sh.old_salary, 0) * 100), 2) AS avg_growth_percentage
FROM salary_history sh
JOIN employees e ON sh.emp_id = e.emp_id
JOIN departments d ON e.dept_id = d.dept_id
WHERE sh.old_salary > 0
GROUP BY d.name;

-- 5. Analytics: Employees due for salary review (No change in 12+ months)
SELECT e.name, MAX(sh.change_date) AS last_review
FROM employees e
JOIN salary_history sh ON e.emp_id = sh.emp_id
GROUP BY e.name
HAVING MAX(sh.change_date) < CURRENT_DATE - INTERVAL '12 months';