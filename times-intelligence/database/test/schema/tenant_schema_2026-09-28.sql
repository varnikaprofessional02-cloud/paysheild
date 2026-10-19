--
-- PostgreSQL database dump
--

\restrict zXUY1WtOWUgpHTRHEGsUS2pp9RsN8ZaBnwy5K7N096E2Xhwekm9yOmKgaOKlJFN

-- Dumped from database version 16.15
-- Dumped by pg_dump version 18.4

-- Started on 2026-09-28 15:54:59

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 6 (class 2615 OID 35516)
-- Name: company; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA company;


ALTER SCHEMA company OWNER TO timesadmin;

--
-- TOC entry 10 (class 2615 OID 35520)
-- Name: employee; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA employee;


ALTER SCHEMA employee OWNER TO timesadmin;

--
-- TOC entry 11 (class 2615 OID 35521)
-- Name: leave; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA leave;


ALTER SCHEMA leave OWNER TO timesadmin;

--
-- TOC entry 9 (class 2615 OID 35519)
-- Name: payroll; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA payroll;


ALTER SCHEMA payroll OWNER TO timesadmin;

--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: azure_pg_admin
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO azure_pg_admin;

--
-- TOC entry 8 (class 2615 OID 35518)
-- Name: report; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA report;


ALTER SCHEMA report OWNER TO timesadmin;

--
-- TOC entry 13 (class 2615 OID 46991)
-- Name: security; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA security;


ALTER SCHEMA security OWNER TO timesadmin;

--
-- TOC entry 7 (class 2615 OID 35517)
-- Name: subscription; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA subscription;


ALTER SCHEMA subscription OWNER TO timesadmin;

--
-- TOC entry 12 (class 2615 OID 35523)
-- Name: timesheet; Type: SCHEMA; Schema: -; Owner: timesadmin
--

CREATE SCHEMA timesheet;


ALTER SCHEMA timesheet OWNER TO timesadmin;

--
-- TOC entry 2525 (class 1247 OID 78013)
-- Name: pay_group_working_type; Type: TYPE; Schema: company; Owner: timesadmin
--

CREATE TYPE company.pay_group_working_type AS ENUM (
    'Full',
    'Off',
    'Both'
);


ALTER TYPE company.pay_group_working_type OWNER TO timesadmin;

--
-- TOC entry 2612 (class 1247 OID 89144)
-- Name: ff_fg_option; Type: TYPE; Schema: employee; Owner: timesadmin
--

CREATE TYPE employee.ff_fg_option AS ENUM (
    'FF',
    'FG'
);


ALTER TYPE employee.ff_fg_option OWNER TO timesadmin;

--
-- TOC entry 2603 (class 1247 OID 89125)
-- Name: residency_type; Type: TYPE; Schema: employee; Owner: timesadmin
--

CREATE TYPE employee.residency_type AS ENUM (
    'SingaporeanOrSPR',
    'WorkPassHolder'
);


ALTER TYPE employee.residency_type OWNER TO timesadmin;

--
-- TOC entry 2606 (class 1247 OID 89130)
-- Name: singaporean_or_spr; Type: TYPE; Schema: employee; Owner: timesadmin
--

CREATE TYPE employee.singaporean_or_spr AS ENUM (
    'Singaporean',
    'SPR'
);


ALTER TYPE employee.singaporean_or_spr OWNER TO timesadmin;

--
-- TOC entry 2609 (class 1247 OID 89136)
-- Name: voluntary_rate_type; Type: TYPE; Schema: employee; Owner: timesadmin
--

CREATE TYPE employee.voluntary_rate_type AS ENUM (
    'BaseCpfFixRate',
    'FullFull',
    'FullGraduated',
    'CustomCPF'
);


ALTER TYPE employee.voluntary_rate_type OWNER TO timesadmin;

--
-- TOC entry 2555 (class 1247 OID 79974)
-- Name: gender_type; Type: TYPE; Schema: public; Owner: timesadmin
--

CREATE TYPE public.gender_type AS ENUM (
    'Male',
    'Female'
);


ALTER TYPE public.gender_type OWNER TO timesadmin;

--
-- TOC entry 2219 (class 1247 OID 52282)
-- Name: principle_type_enum; Type: TYPE; Schema: public; Owner: timesadmin
--

CREATE TYPE public.principle_type_enum AS ENUM (
    'user',
    'role',
    'user-company'
);


ALTER TYPE public.principle_type_enum OWNER TO timesadmin;

--
-- TOC entry 2216 (class 1247 OID 52276)
-- Name: resource_type_enum; Type: TYPE; Schema: public; Owner: timesadmin
--

CREATE TYPE public.resource_type_enum AS ENUM (
    'feature',
    'field',
    'function',
    'other'
);


ALTER TYPE public.resource_type_enum OWNER TO timesadmin;

--
-- TOC entry 2423 (class 1247 OID 66828)
-- Name: user_enrollment_notification_type; Type: TYPE; Schema: security; Owner: timesadmin
--

CREATE TYPE security.user_enrollment_notification_type AS ENUM (
    'Email',
    'Phone',
    'SMS',
    'WhatsApp'
);


ALTER TYPE security.user_enrollment_notification_type OWNER TO timesadmin;

--
-- TOC entry 982 (class 1255 OID 112042)
-- Name: get_allowance_deduction_by_code(integer, text); Type: FUNCTION; Schema: company; Owner: timesadmin
--

CREATE FUNCTION company.get_allowance_deduction_by_code(p_company_id integer, p_code text) RETURNS TABLE(paycode text, paycodedescription text, paycodetypecode text, cpfcode text)
    LANGUAGE sql STABLE ROWS 1 PARALLEL SAFE
    AS $$
    SELECT
        ad.code        AS PayCode,
        ad.description AS PayCodeDescription,
        adt.code       AS PayCodeTypeCode,
        adcpf.code     AS CpfCode
    FROM company.allowance_deduction ad
        INNER JOIN company.allowance_deduction_type adt ON ad.type_id = adt.id
        INNER JOIN company.allowance_deduction_cpf  adcpf ON ad.cpf_id = adcpf.id
    WHERE ad.company_id = p_company_id
      AND ad.code = p_code
    ORDER BY ad.year DESC
    LIMIT 1;
$$;


ALTER FUNCTION company.get_allowance_deduction_by_code(p_company_id integer, p_code text) OWNER TO timesadmin;

--
-- TOC entry 970 (class 1255 OID 107273)
-- Name: get_paygroup_calendar_by_id(bigint); Type: FUNCTION; Schema: company; Owner: timesadmin
--

CREATE FUNCTION company.get_paygroup_calendar_by_id(p_pay_group_id bigint) RETURNS TABLE(period text, startdate date, middate date, enddate date, firsthalf numeric, secondhalf numeric, otstartdate date, otmiddate date, otenddate date)
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
      SELECT
          c.period          AS Period,
          c.start_date      AS StartDate,
          c.mid_date        AS MidDate,
          c.end_date        AS EndDate,
          c.first_half      AS FirstHalf,
          c.second_half     AS SecondHalf,
          c.ot_start_date   AS OTStartDate,
          c.ot_mid_date     AS OTMidDate,
          c.ot_end_date     AS OTEndDate
      FROM company.pay_group_calendar c
      WHERE c.pay_group_id = p_pay_group_id
      ORDER BY c.id;
  
$$;


ALTER FUNCTION company.get_paygroup_calendar_by_id(p_pay_group_id bigint) OWNER TO timesadmin;

--
-- TOC entry 971 (class 1255 OID 107274)
-- Name: get_prorate_payitem_formula_by_company_id(bigint); Type: FUNCTION; Schema: company; Owner: timesadmin
--

CREATE FUNCTION company.get_prorate_payitem_formula_by_company_id(p_company_id bigint) RETURNS TABLE(id bigint, companyid bigint, proratepayitemformulaid bigint, otformula boolean, rdformula boolean, nplformula boolean, absentformula boolean, grpformula boolean, proratepayitemuid uuid, proratepayitemname text)
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
 

SELECT 
	pac.id AS Id, 
	pac.company_id AS CompanyId, 
	pac.prorate_payitem_formula_id AS ProratePayitemFormulaId, 
	pac.ot_formula AS OtFormula, 
	pac.rd_formula AS RdFormula, 
	pac.npl_formula AS NplFormula, 
	pac.absent_formula AS AbsentFormula, 
	pac.grp_formula AS GrpFormula,
	pf.uid AS ProratePayItemUid,
	pf.name AS ProratePayItemName
	FROM company.prorate_allowance_configuration pac 
	INNER JOIN company.lk_prorate_formula pf
	ON  pac.prorate_payitem_formula_id = pf.id
	
    WHERE pac.company_id = p_company_id;

$$;


ALTER FUNCTION company.get_prorate_payitem_formula_by_company_id(p_company_id bigint) OWNER TO timesadmin;

--
-- TOC entry 972 (class 1255 OID 107275)
-- Name: get_prorate_salary_formula_by_company_id(bigint); Type: FUNCTION; Schema: company; Owner: timesadmin
--

CREATE FUNCTION company.get_prorate_salary_formula_by_company_id(p_company_id bigint) RETURNS TABLE(id bigint, companyid bigint, isproratenewhired boolean, proratesalaryformulaid bigint, formulasetupmethodid bigint, proratesalaryformulaguid uuid, proratesalaryformulaname text)
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
 
	SELECT 
		fss.id AS Id, 
		fss.company_id AS CompanyId, 
		fss.prorate_new_hired AS IsProrateNewHired, 
		fss.prorate_salary_formula_id AS ProrateSalaryFormulaId, 
		fss.formula_setup_method_id AS FormulaSetupMethodId, 
		psf.uid AS ProrateSalaryFormulaGuid, 
		psf.name AS ProrateSalaryFormulaName
	FROM company.formula_setup_settings fss
	INNER JOIN company.lk_prorate_salary_formula psf
	ON fss.prorate_salary_formula_id = psf.id
    WHERE fss.company_id = p_company_id;

$$;


ALTER FUNCTION company.get_prorate_salary_formula_by_company_id(p_company_id bigint) OWNER TO timesadmin;

--
-- TOC entry 943 (class 1255 OID 112126)
-- Name: get_allowance_deduction_by_employee_contract(bigint, date, date); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_allowance_deduction_by_employee_contract(p_contractid bigint, p_period_start date, p_period_end date) RETURNS TABLE(contract_id bigint, id bigint, uid uuid, contractuid uuid, paycodetypecode text, paycodetype text, paycodeid bigint, paycodeuid uuid, paycode text, paycodedescription text, prorateformulaid bigint, isprorate boolean, cpfcode text, cpfname text, amounttypeuid uuid, amounttypecode text, amounttypename text, currencycodeuid uuid, currencycode text, effectivedate date, paymentdate date, enddate date, recurringmethoduid uuid, recurringmethodcode text, recurringmethodname text, amount numeric, payrollcycleuid uuid, payrollcyclecode text, payrollcyclename text, isaffectedlastpaymentdate boolean, isweek1 boolean, isweek2 boolean, isweek3 boolean, isweek4 boolean, isweek5 boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_period_start date;
    v_period_end   date;
BEGIN
    -- Pay period is supplied by the caller (frontend MM/yyyy -> C# PayrollCycle.PeriodStart/PeriodEnd).
    v_period_start := p_period_start;
    v_period_end   := p_period_end;

    RETURN QUERY	
	
 SELECT
	cad.contract_id,
     cad.id                              AS Id,
     cad.uid                             AS Uid,
     ucc.uid                             AS ContractUid,
     adt.code                            AS PayCodeTypeCode,
     adt.name                            AS PayCodeType,
	 ad.id 								  AS PayCodeId,
     ad.uid                              AS PayCodeUid,
     ad.code                             AS PayCode,
     ad.description                      AS PayCodeDescription,
   	 pra.prorate_payitem_formula_id 	  AS ProrateFormulaId,
	 case when pra.company_allowance_deduction_id is not null
		then true else false end 		  AS IsProrate,	 
	 adcpf.code                          AS CpfCode,  
     adcpf.name                          AS CpfName,  
     lat.uid                             AS AmountTypeUid,
     lat.code                            AS AmountTypeCode,
     lat.name                            AS AmountTypeName,
     cs.uid                              AS CurrencyCodeUid,
     cs.code                             AS CurrencyCode,
     cad.effective_date                  AS EffectiveDate,
     cad.payment_date                    AS PaymentDate,
     cad.end_date                        AS EndDate,
     lrm.uid                             AS RecurringMethodUid,
     lrm.code                            AS RecurringMethodCode,
     lrm.name                            AS RecurringMethodName,
     cad.amount                          AS Amount,
     lpc.uid                             AS PayrollCycleUid,
     lpc.code                            AS PayrollCycleCode,
     lpc.name                            AS PayrollCycleName,
     cad.is_affected_last_payment_date   AS IsAffectedLastPaymentDate,
     cad.is_week_1                       AS IsWeek1,
     cad.is_week_2                       AS IsWeek2,
     cad.is_week_3                       AS IsWeek3,
     cad.is_week_4                       AS IsWeek4,
     cad.is_week_5                       AS IsWeek5  

	 FROM employee.contract_allowance_deduction cad
     INNER JOIN employee.user_company_contract ucc
         ON cad.contract_id = ucc.id
     INNER JOIN company.allowance_deduction ad
         ON cad.pay_code_id = ad.id
     INNER JOIN company.allowance_deduction_type adt
         ON ad.type_id = adt.id
     INNER JOIN employee.lk_amount_type lat
         ON cad.amount_type_id = lat.id
     INNER JOIN company.code_setup cs
         ON cad.currency_code_id = cs.id
         AND cad.currency_code_type_id = cs.code_setup_type_id
     INNER JOIN employee.lk_recurring_method lrm
         ON cad.recurring_method_id = lrm.id
     INNER JOIN payroll.lk_payroll_cycle lpc
         ON cad.payroll_cycle_id = lpc.id
     INNER JOIN company.allowance_deduction_cpf adcpf   -- new; INNER ok, ad.cpf_id is NOT NULL + FK
         ON ad.cpf_id = adcpf.id

     LEFT JOIN company.prorate_allowance_deduction_assignment pra
	     ON cad.pay_code_id = pra.company_allowance_deduction_id

     LEFT JOIN security.user auditor
         ON auditor.email = COALESCE(cad.updated_by, cad.created_by)
 	WHERE 	
		cad.contract_id = p_contractid AND
		-- active-window overlap (matches the engine's recurring-method IsWithinActiveWindow): return the
		-- row for EVERY period the component spans, not only the period its effective_date lands in. The
		-- recurring-method providers then decide per cycle (monthly = every cycle, non-recurring = only the
		-- payment-date cycle), and the pay-component history check prevents paying the same one twice.
		cad.effective_date <= v_period_end AND
		(cad.end_date IS NULL OR cad.end_date >= v_period_start)
 	ORDER BY cad.created_on DESC, cad.id DESC;

END;
$$;


ALTER FUNCTION employee.get_allowance_deduction_by_employee_contract(p_contractid bigint, p_period_start date, p_period_end date) OWNER TO timesadmin;

--
-- TOC entry 936 (class 1255 OID 114462)
-- Name: get_company_id_by_pay_run_uid(uuid); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_company_id_by_pay_run_uid(p_pay_run_uid uuid) RETURNS TABLE(companyid integer)
    LANGUAGE sql STABLE
    AS $$
    SELECT per.company_id::integer
    FROM payroll.pay_run run
    JOIN payroll.pay_period per ON per.id = run.pay_period_id
    WHERE run.uid = p_pay_run_uid
    LIMIT 1;
$$;


ALTER FUNCTION employee.get_company_id_by_pay_run_uid(p_pay_run_uid uuid) OWNER TO timesadmin;

--
-- TOC entry 984 (class 1255 OID 113537)
-- Name: get_company_mid_month_policy(integer); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_company_mid_month_policy(p_company_id integer) RETURNS TABLE(subjecttocpf boolean, cpfwagetimesfactor2 boolean, subjecttocomfund boolean, subjecttosdf boolean)
    LANGUAGE sql STABLE
    AS $$
    SELECT COALESCE(ps.mid_month_subject_to_cpf, false),
           COALESCE(ps.mid_month_cpf_wage_times_factor_2, false),
           COALESCE(ps.mid_month_subject_to_com_fund, false),
           COALESCE(ps.mid_month_subject_to_sdf, false)
    FROM payroll.sg_payroll_settings ps
    WHERE ps.company_id = p_company_id
    LIMIT 1;
$$;


ALTER FUNCTION employee.get_company_mid_month_policy(p_company_id integer) OWNER TO timesadmin;

--
-- TOC entry 977 (class 1255 OID 107286)
-- Name: get_employee_contract(integer); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract(p_employeeid integer) RETURNS TABLE(employeeid integer, contractid text)
    LANGUAGE sql
    AS $$
	
SELECT 
	u.id AS EmployeeId,
	c.contract_id AS ContractId
		
    FROM employee.user_company_contract c
    JOIN security.user u
    ON u.id = c.user_id
	
    WHERE 
		c.is_active = TRUE and 
		u.id = p_employeeId;
$$;


ALTER FUNCTION employee.get_employee_contract(p_employeeid integer) OWNER TO timesadmin;

--
-- TOC entry 978 (class 1255 OID 108244)
-- Name: get_employee_contract_by_employeeid(integer, date, date); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_by_employeeid(p_employeeid integer, p_period_start date, p_period_end date) RETURNS TABLE(employeeid integer, fullname text, emailaddress text, contractdbid bigint, contractid text, hireddate date, resignationdate date, lastpaymentdate date, type text, startdate date, enddate date, isactive boolean, effectiveservicedate date, excludepayroll boolean, stoppaymenteffectivedate date, stoppaymentenddate date, employeeno text, staffcardno text, phonenumber text, designation text, jobgradename text, joblevelname text, costcentrename text, divisionname text, departmentname text, sectionname text, unitname text, teamname text, branchname text, locationname text, probationperiod integer, probationtype text, confirmationdate date, salary numeric, salaryeff numeric, salarynext numeric, paymentprofileid text, cpfaccountno text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_period_start date;
    v_period_end   date;
BEGIN
    v_period_start := p_period_start;
    v_period_end   := p_period_end;

    RETURN QUERY
    SELECT
        u.id                                AS EmployeeId,
        u.full_name::text                   AS FullName,
        u.email::text                       AS EmailAddress,
        c.id                                AS ContractDbId,
        c.contract_id                       AS ContractId,
        c.contract_start_date::date         AS HiredDate,
        cr.resignation_date::date           AS ResignationDate,
        cr.last_payment_date::date          AS LastPaymentDate,
        NULL::text                          AS Type,
        c.contract_start_date::date         AS StartDate,
        c.contract_end_date::date           AS EndDate,
        c.is_active::boolean                AS IsActive,
        c.effective_service_date::date      AS EffectiveServiceDate,
        c.is_exclude_payroll::boolean       AS ExcludePayroll,
        sp.effective_date::date             AS StopPaymentEffectiveDate,
        sp.end_date::date                   AS StopPaymentEndDate,
        c.employee_no                       AS EmployeeNo,
        c.staff_card_no                     AS StaffCardNo,
        c.office_phone_no                   AS PhoneNumber,

        -- Position + organization NAMES, from the career-progression row in effect for the pay period.
        occ.description::text               AS Designation,
        jg.description::text                AS JobGradeName,
        jl.description::text                AS JobLevelName,
        ctr.description::text               AS CostCentreName,
        dv.description::text                AS DivisionName,
        dep.description::text               AS DepartmentName,
        sec.description::text               AS SectionName,
        un.description::text                AS UnitName,
        tm.description::text                AS TeamName,
        br.description::text                AS BranchName,
        lo.description::text                AS LocationName,

        c.probation_period                  AS ProbationPeriod,
        c.probation_period_type_id::text    AS ProbationType,
        c.confirmation_date::date           AS ConfirmationDate,

        COALESCE(sal_eff.new_salary, sal_next.new_salary)::numeric AS Salary,
        sal_eff.new_salary::numeric         AS SalaryEff,
        sal_next.new_salary::numeric        AS SalaryNext,

        c.payment_profile_id::text          AS PaymentProfileId,
        cpf.cpf_number::text                AS CPFAccountNo

    FROM employee.user_company_contract c
    JOIN security.user u
        ON u.id = c.user_id
    JOIN company.code_setup ct
        ON  ct.id = c.contract_type_id
        AND ct.code_setup_type_id = c.contract_type_code_id

    -- Career-progression row IN EFFECT at period start (carries salary AND position/org).
    LEFT JOIN LATERAL (
        SELECT cp.new_salary, cp.effective_date,
               cp.occupation_id,  cp.occupation_type_id,
               cp.job_grade_id,   cp.job_grade_type_id,
               cp.job_level_id,   cp.job_level_type_id,
               cp.cost_centre_id, cp.cost_centre_type_id,
               cp.division_id,    cp.division_type_id,
               cp.department_id,  cp.department_type_id,
               cp.section_id,     cp.section_type_id,
               cp.unit_id,        cp.unit_type_id,
               cp.team_id,        cp.team_type_id,
               cp.branch_id,      cp.branch_type_id,
               cp.location_id,    cp.location_type_id
        FROM   employee.career_progression cp
        WHERE  cp.contract_id    = c.id
          AND  cp.effective_date <= v_period_start
        ORDER BY cp.effective_date DESC, cp.id DESC
        LIMIT 1
    ) sal_eff ON TRUE

    -- NEXT career-progression change on/after period start (fallback + mid-period detection).
    LEFT JOIN LATERAL (
        SELECT cp.new_salary, cp.effective_date,
               cp.occupation_id,  cp.occupation_type_id,
               cp.job_grade_id,   cp.job_grade_type_id,
               cp.job_level_id,   cp.job_level_type_id,
               cp.cost_centre_id, cp.cost_centre_type_id,
               cp.division_id,    cp.division_type_id,
               cp.department_id,  cp.department_type_id,
               cp.section_id,     cp.section_type_id,
               cp.unit_id,        cp.unit_type_id,
               cp.team_id,        cp.team_type_id,
               cp.branch_id,      cp.branch_type_id,
               cp.location_id,    cp.location_type_id
        FROM   employee.career_progression cp
        WHERE  cp.contract_id    = c.id
          AND  cp.effective_date > v_period_start
        ORDER BY cp.effective_date ASC, cp.id ASC
        LIMIT 1
    ) sal_next ON TRUE

    -- Resolve each position/org id to its code_setup description (in-effect row, else next).
    LEFT JOIN company.code_setup occ ON occ.id = COALESCE(sal_eff.occupation_id,  sal_next.occupation_id)  AND occ.code_setup_type_id = COALESCE(sal_eff.occupation_type_id,  sal_next.occupation_type_id)
    LEFT JOIN company.code_setup jg  ON jg.id  = COALESCE(sal_eff.job_grade_id,   sal_next.job_grade_id)   AND jg.code_setup_type_id  = COALESCE(sal_eff.job_grade_type_id,   sal_next.job_grade_type_id)
    LEFT JOIN company.code_setup jl  ON jl.id  = COALESCE(sal_eff.job_level_id,   sal_next.job_level_id)   AND jl.code_setup_type_id  = COALESCE(sal_eff.job_level_type_id,   sal_next.job_level_type_id)
    LEFT JOIN company.code_setup ctr ON ctr.id = COALESCE(sal_eff.cost_centre_id, sal_next.cost_centre_id) AND ctr.code_setup_type_id = COALESCE(sal_eff.cost_centre_type_id, sal_next.cost_centre_type_id)
    LEFT JOIN company.code_setup dv  ON dv.id  = COALESCE(sal_eff.division_id,    sal_next.division_id)    AND dv.code_setup_type_id  = COALESCE(sal_eff.division_type_id,    sal_next.division_type_id)
    LEFT JOIN company.code_setup dep ON dep.id = COALESCE(sal_eff.department_id,  sal_next.department_id)  AND dep.code_setup_type_id = COALESCE(sal_eff.department_type_id,  sal_next.department_type_id)
    LEFT JOIN company.code_setup sec ON sec.id = COALESCE(sal_eff.section_id,     sal_next.section_id)     AND sec.code_setup_type_id = COALESCE(sal_eff.section_type_id,     sal_next.section_type_id)
    LEFT JOIN company.code_setup un  ON un.id  = COALESCE(sal_eff.unit_id,        sal_next.unit_id)        AND un.code_setup_type_id  = COALESCE(sal_eff.unit_type_id,        sal_next.unit_type_id)
    LEFT JOIN company.code_setup tm  ON tm.id  = COALESCE(sal_eff.team_id,        sal_next.team_id)        AND tm.code_setup_type_id  = COALESCE(sal_eff.team_type_id,        sal_next.team_type_id)
    LEFT JOIN company.code_setup br  ON br.id  = COALESCE(sal_eff.branch_id,      sal_next.branch_id)      AND br.code_setup_type_id  = COALESCE(sal_eff.branch_type_id,      sal_next.branch_type_id)
    LEFT JOIN company.code_setup lo  ON lo.id  = COALESCE(sal_eff.location_id,    sal_next.location_id)    AND lo.code_setup_type_id  = COALESCE(sal_eff.location_type_id,    sal_next.location_type_id)

    LEFT JOIN employee.lk_service_grade sg
        ON sg.id = c.service_grade_id
    JOIN company.period_type pt
        ON pt.id = c.probation_period_type_id
    JOIN company.code_setup cc
        ON  cc.id = c.currency_code_id
        AND cc.code_setup_type_id = c.currency_code_type_id
    JOIN company.payment_profile pp
        ON pp.id = c.payment_profile_id
    LEFT JOIN company.sg_provident_fund cpf
        ON cpf.id = c.sg_provident_fund_id
    LEFT JOIN company.my_provident_fund epf
        ON epf.id = c.my_provident_fund_id
    LEFT JOIN company.id_provident_fund bpjs
        ON bpjs.id = c.id_provident_fund_id

    LEFT JOIN employee.contract_resignation cr
        ON c.id = cr.contract_id

    -- Stop-payment window overlapping the current pay period (latest if several).
    LEFT JOIN LATERAL (
        SELECT sp.effective_date, sp.end_date
        FROM   employee.contract_stop_payment sp
        WHERE  sp.contract_id     = c.id
          AND  sp.effective_date <= v_period_end
          AND  (sp.end_date IS NULL OR sp.end_date >= v_period_start)
        ORDER BY sp.effective_date DESC
        LIMIT 1
    ) sp ON TRUE

    WHERE
        c.is_active = TRUE AND
        c.is_exclude_payroll = FALSE AND
        u.id = p_employeeid;
END;
$$;


ALTER FUNCTION employee.get_employee_contract_by_employeeid(p_employeeid integer, p_period_start date, p_period_end date) OWNER TO timesadmin;

--
-- TOC entry 973 (class 1255 OID 107280)
-- Name: get_employee_contract_careerprogression(integer, text, integer); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_careerprogression(p_employeeid integer, p_contractid text, p_payrollcycleid integer) RETURNS TABLE(employeeid integer, contractid text, code text, description text, reason text, effectivedate date, payeffectivedate date, adjustedamount numeric)
    LANGUAGE sql
    AS $$
	
SELECT 
	u.id AS EmployeeId,
	c.contract_id AS ContractId,
	cpc.code AS Code,
    cpc.description AS Description,
	cp.reason AS Reason,
	cp.effective_date AS EffectiveDate,
	cp.pay_effective_date AS PayEffectiveDate,
	cp.adjusted_amount AS AdjustedAmount
		
    FROM employee.user_company_contract c
    JOIN security.user u
    ON u.id = c.user_id
    JOIN company.code_setup ct
    ON ct.id = c.contract_type_id
    AND ct.code_setup_type_id = c.contract_type_code_id
	JOIN employee.career_progression cp
	ON c.id = cp.contract_id
    JOIN company.code_setup cc
    ON cc.id = c.currency_code_id
    AND cc.code_setup_type_id = c.currency_code_type_id
JOIN company.code_setup cpc
    ON cpc.id = cp.career_progression_code_id
    AND cpc.code_setup_type_id = cp.career_progression_code_type_id
    WHERE 
		c.is_active = TRUE and 
		cpc.code != 'CONSTART' and --exclude this
	
		u.id = p_employeeId and 
		c.contract_id = p_contractid; 

$$;


ALTER FUNCTION employee.get_employee_contract_careerprogression(p_employeeid integer, p_contractid text, p_payrollcycleid integer) OWNER TO timesadmin;

--
-- TOC entry 974 (class 1255 OID 107281)
-- Name: get_employee_contract_cpf_history(integer, text, integer); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_cpf_history(p_employeeid integer, p_contractid text, p_payrollcycleid integer) RETURNS TABLE(employeeid integer, contractid text, hireddate date, resignationdate date, basicsalary numeric)
    LANGUAGE sql
    AS $$
	
SELECT 
	u.id AS EmployeeId,
	c.contract_id AS ContractId,
	c.contract_start_date AS HiredDate,
	c.contract_end_date AS ResignationDate,
	cp.new_salary AS BasicSalary
		
    FROM employee.user_company_contract c
    JOIN security.user u
    ON u.id = c.user_id
    JOIN company.code_setup ct
    ON ct.id = c.contract_type_id
    AND ct.code_setup_type_id = c.contract_type_code_id
	JOIN employee.career_progression cp
	ON c.id = cp.contract_id
    LEFT JOIN employee.lk_service_grade sg
    ON sg.id = c.service_grade_id
    JOIN company.period_type pt
    ON pt.id = c.probation_period_type_id
    JOIN company.code_setup cc
    ON cc.id = c.currency_code_id
    AND cc.code_setup_type_id = c.currency_code_type_id
    JOIN company.payment_profile pp
    ON pp.id = c.payment_profile_id
    LEFT JOIN company.sg_provident_fund cpf
    ON cpf.id = c.sg_provident_fund_id
    LEFT JOIN company.my_provident_fund epf
    ON epf.id = c.my_provident_fund_id
    LEFT JOIN company.id_provident_fund bpjs
    ON bpjs.id = c.id_provident_fund_id
    WHERE 
		c.is_active = TRUE and 
	
		u.id = p_employeeId and 
		c.contract_id = p_contractid; 

$$;


ALTER FUNCTION employee.get_employee_contract_cpf_history(p_employeeid integer, p_contractid text, p_payrollcycleid integer) OWNER TO timesadmin;

--
-- TOC entry 986 (class 1255 OID 113538)
-- Name: get_employee_contract_mid_month_pay_history(integer, bigint, integer, text); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_mid_month_pay_history(p_employee_id integer, p_contract_id bigint, p_company_id integer, p_period text) RETURNS TABLE(payrollrunid bigint, amount numeric, cpfwage numeric, employeecpf numeric, employercpf numeric, communityfunds numeric, sdl numeric)
    LANGUAGE sql STABLE
    AS $$
    SELECT pr.pay_run_id::bigint,
           COALESCE(pr.basic_salary, 0)::numeric,
           COALESCE((pr.data_processed #>> '{payRecord,grossPay,amount}')::numeric, 0),
           COALESCE((pr.data_processed #>> '{payRecord,cpfCalculationResult,totalEmployeeContribution,amount}')::numeric, 0),
           COALESCE((pr.data_processed #>> '{payRecord,cpfCalculationResult,totalEmployerContribution,amount}')::numeric, 0),
           COALESCE((pr.data_processed #>> '{payRecord,communityFundsCalculationResult,totalAmount,amount}')::numeric, 0),
           COALESCE((pr.data_processed #>> '{payRecord,sdlCalculationResult,amount,amount}')::numeric, 0)
    FROM payroll.pay_record pr
    JOIN payroll.pay_run run          ON run.id = pr.pay_run_id
    JOIN payroll.pay_period per       ON per.id = run.pay_period_id
    JOIN payroll.lk_payroll_cycle cyc ON cyc.id = run.pay_cycle_id
    WHERE pr.user_id = p_employee_id
      AND pr.contract_id = p_contract_id
      AND pr.status_id = 2                      -- Completed (PayRunStatusEnum in times-payroll-api)
      AND upper(trim(cyc.code)) = 'MID'
      AND per.company_id = p_company_id
      AND per.value = p_period;
$$;


ALTER FUNCTION employee.get_employee_contract_mid_month_pay_history(p_employee_id integer, p_contract_id bigint, p_company_id integer, p_period text) OWNER TO timesadmin;

--
-- TOC entry 976 (class 1255 OID 107283)
-- Name: get_employee_contract_paycomponent(integer, text, date, date); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_paycomponent(p_employeeid integer, p_contractid text, p_period_start date, p_period_end date) RETURNS TABLE(employeeid integer, contractid text, hireddate date, resignationdate date, basicsalary numeric, contract_id bigint, uid uuid, contractuid uuid, paycodetypecode text, paycodetype text, paycodeuid uuid, paycode text, paycodedescription text, isprorate boolean, cpfcode text, cpfname text, amounttypeuid uuid, amounttypecode text, amounttypename text, currencycodeuid uuid, currencycode text, effectivedate date, paymentdate date, enddate date, recurringmethoduid uuid, recurringmethodcode text, recurringmethodname text, amount numeric, payrollcycleuid uuid, payrollcyclecode text, payrollcyclename text, isaffectedlastpaymentdate boolean, isweek1 boolean, isweek2 boolean, isweek3 boolean, isweek4 boolean, isweek5 boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN 

    RETURN QUERY	
	
	SELECT 
		u.id AS EmployeeId,
		c.contract_id AS ContractId,
		c.contract_start_date::date AS HiredDate,
		c.contract_end_date::date AS ResignationDate,
		cp.new_salary AS BasicSalary,
	
		adc.contract_id,
		adc.uid,
		adc.contractuid,
		adc.paycodetypecode,
		adc.paycodetype,
		adc.paycodeuid,
		adc.paycode,
		adc.paycodedescription,
		adc.isprorate,
		adc.cpfcode,
		adc.cpfname,
		adc.amounttypeuid,
		adc.amounttypecode,
		adc.amounttypename,
		adc.currencycodeuid,
		adc.currencycode,
		adc.effectivedate,
		adc.paymentdate,
		adc.enddate,
		adc.recurringmethoduid,
		adc.recurringmethodcode,
		adc.recurringmethodname,
		adc.amount,
		adc.payrollcycleuid,
		adc.payrollcyclecode,
		adc.payrollcyclename,
		adc.isaffectedlastpaymentdate,
		adc.isweek1,
		adc.isweek2,
		adc.isweek3,
		adc.isweek4,
		adc.isweek5
	
	    FROM employee.user_company_contract c
	    JOIN security.user u
	    ON u.id = c.user_id
		
	    JOIN company.code_setup ct
	    ON
			ct.id = c.contract_type_id AND 
			ct.code_setup_type_id = c.contract_type_code_id
		
		JOIN employee.career_progression cp
		ON c.id = cp.contract_id
		 
		JOIN employee.get_allowance_deduction_by_employee_contract(c.id, p_period_start, p_period_end) AS adc --from employee api repo
		ON c.id = adc.contract_id
	
	    WHERE 
			c.is_active = TRUE 
		
		and 
			--u.id = 3 and c.contract_id = 'CTR-2026-IY2FMHTPI'; 
	
			u.id = p_employeeId and 
			c.contract_id = p_contractid; 
END;
$$;


ALTER FUNCTION employee.get_employee_contract_paycomponent(p_employeeid integer, p_contractid text, p_period_start date, p_period_end date) OWNER TO timesadmin;

--
-- TOC entry 975 (class 1255 OID 107282)
-- Name: get_employee_contract_paycomponent_history(integer, text, date, date); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_paycomponent_history(p_employeeid integer, p_contractid text, p_period_start date, p_period_end date) RETURNS TABLE(payrollrunid integer, employeeid integer, contractid text, paycode text, recurringmethodcode text, effectivedate date, paymentdate date, periodstart date, amount numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN

    RETURN QUERY

    SELECT
        u.id                          AS PayrollRunId,
        u.id                          AS EmployeeId,
        c.contract_id                 AS ContractId,
        'UNION'::text                 AS PayCode,
        'MON'::text                   AS RecurringMethodCode,
        c.contract_start_date::date   AS EffectiveDate,
        c.contract_start_date::date   AS PaymentDate,
        c.contract_start_date::date   AS PeriodStart,
        88::numeric                   AS Amount

    FROM employee.user_company_contract c
    JOIN security.user u
    ON u.id = c.user_id

    JOIN company.code_setup ct
    ON
                ct.id = c.contract_type_id AND
                ct.code_setup_type_id = c.contract_type_code_id

        JOIN employee.career_progression cp
        ON c.id = cp.contract_id

        JOIN employee.get_allowance_deduction_by_employee_contract(c.id, p_period_start, p_period_end) AS adc --from employee api repo
        ON c.id = adc.contract_id

    WHERE
        u.id = 9999;   --note: (placeholder for now) does not have to return any records!

        /*
                c.is_active = TRUE AND
                u.id = p_employeeId AND
                c.contract_id = p_contractid;
        */

--SELECT * FROM employee.get_employee_contract_paycomponent_history(2, 'CTR-2026-SVL7SKW6V', DATE '2026-08-01', DATE '2026-08-31')
END;
$$;


ALTER FUNCTION employee.get_employee_contract_paycomponent_history(p_employeeid integer, p_contractid text, p_period_start date, p_period_end date) OWNER TO timesadmin;

--
-- TOC entry 980 (class 1255 OID 110530)
-- Name: get_employee_contract_paysetting(integer, text, integer); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_paysetting(p_employeeid integer, p_contractid text, p_payrollcycleid integer) RETURNS TABLE(employeeid integer, contractid text, hireddate date, resignationdate date, basicsalary numeric, paygroupid integer, paygroupname text, paytypeid integer, paytypecodeid integer, ismidmonthpaypercentage boolean, midmonthpay numeric, issemimonth boolean, bonusfactor numeric, dailyrateformulaid integer, hourlyrateformulaid integer, workingcodeid integer, workcodesalarymonth integer, festivaladvanceid integer, hourworkedperyear numeric, dayworkedperweek numeric, code text)
    LANGUAGE sql
    AS $$

SELECT 
	u.id AS EmployeeId,
	c.contract_id AS ContractId,
	c.contract_start_date AS HiredDate,
	c.contract_end_date AS ResignationDate,
	cp.new_salary AS BasicSalary,
	ps.pay_group_id AS PayGroupId,	
	pg.pay_group::text AS PayGroupName,
	ps.pay_type_id AS PayTypeId,
	ps.pay_type_code_id AS PayTypeCodeId,	
	ps.is_mid_month_pay_percentage AS IsMidMonthPayPercentage,
	ps.mid_month_pay AS MidMonthPay,
	ps.is_semi_month AS IsSemiMonth,
	ps.bonus_factor AS BonusFactor,
	ps.daily_rate_formula_id AS DailyRateFormulaId,	
	ps.hourly_rate_formula_id AS HourlyRateFormulaId,
	ps.working_code_id AS WorkingCodeId,
	ps.work_code_salary_month AS WorkCodeSalaryMonth,
	ps.festival_advance_id AS FestivalAdvanceId,
	ps.hour_worked_per_year AS HourWorkedPerYear,
	ps.day_worked_per_week AS DayWorkedPerWeek,
	cpc.code AS Code
		
    FROM employee.user_company_contract c
    JOIN security.user u
    ON u.id = c.user_id

    -- metadata lookup only (columns not selected) - don't drop the contract over a bad FK
    LEFT JOIN company.code_setup ct
    ON
		ct.id = c.contract_type_id AND 
		ct.code_setup_type_id = c.contract_type_code_id
		
	JOIN employee.career_progression cp
	ON c.id = cp.contract_id

    JOIN company.code_setup cpc
    ON cpc.id = cp.career_progression_code_id
    AND cpc.code_setup_type_id = cp.career_progression_code_type_id

	JOIN employee.contract_pay_setting ps 
	ON c.id = ps.contract_id
	
	JOIN company.pay_group pg 
	ON pg.id = ps.pay_group_id

    WHERE 
		cpc.code = 'CONSTART' and
		u.id = p_employeeId and 
		c.contract_id = p_contractid; 
	
$$;


ALTER FUNCTION employee.get_employee_contract_paysetting(p_employeeid integer, p_contractid text, p_payrollcycleid integer) OWNER TO timesadmin;

--
-- TOC entry 981 (class 1255 OID 110531)
-- Name: get_employee_contract_workcalendar(integer, text, integer); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employee_contract_workcalendar(p_employeeid integer, p_contractid text, p_payrollcycleid integer) RETURNS TABLE(employeeid integer, contractid text, hireddate date, resignationdate date, basicsalary numeric, weeklysettings jsonb, yearlycalendarsettings jsonb)
    LANGUAGE sql
    AS $$
	
SELECT 
	u.id AS EmployeeId,
	c.contract_id AS ContractId,
	c.contract_start_date AS HiredDate,
	c.contract_end_date AS ResignationDate,
	cp.new_salary AS BasicSalary,
	pswc.weekly_setting AS WeeklySettings,
    pswc.yearly_calendar_setting AS YearlyCalendarSettings
		
    FROM employee.user_company_contract c
    JOIN security.user u
    ON u.id = c.user_id

    -- metadata lookup only (columns not selected) - don't drop the contract over a bad FK
    LEFT JOIN company.code_setup ct
    ON ct.id = c.contract_type_id
    AND ct.code_setup_type_id = c.contract_type_code_id

	LEFT JOIN employee.career_progression cp
	ON c.id = cp.contract_id

	LEFT JOIN employee.contract_pay_setting cps
    ON cps.contract_id = c.id
	LEFT JOIN employee.pay_setting_work_calendar pswc
    ON pswc.pay_setting_id = cps.id
	 WHERE 
		u.id = p_employeeId and 
		c.contract_id = p_contractid
	LIMIT 1
	; 

$$;


ALTER FUNCTION employee.get_employee_contract_workcalendar(p_employeeid integer, p_contractid text, p_payrollcycleid integer) OWNER TO timesadmin;

--
-- TOC entry 979 (class 1255 OID 108956)
-- Name: get_employees_by_company_id(integer, uuid[]); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_employees_by_company_id(p_companyid integer, p_user_uids uuid[]) RETURNS TABLE(employeeid integer, fullname text, emailaddress text, userstatus integer, userrolestatus integer, hascontract boolean, hasbankdetails boolean, communityfundcode1 text, communityfundcode2 text, commfund1optedin boolean, commfund2optedin boolean, race text, religion text, citizenship text, citizenshipcode text, dateofbirth date, isspr boolean, sprapproveddate date)
    LANGUAGE sql
    AS $$

	SELECT
		u.id                              AS Employeeid,
		u.full_name::text                 AS FullName,
		u.email::text                     AS EmailAddress,
		u.user_status_id                  AS UserStatus,
		COALESCE(ucr.user_role_status_id, 2) AS UserRoleStatus,   -- missing role -> Inactive (excluded)
		EXISTS (SELECT 1 FROM employee.user_company_contract c WHERE c.user_id = u.id) AS HasContract,
		EXISTS (SELECT 1 FROM employee.payment_profile      pp WHERE pp.user_id = u.id) AS HasBankDetails,
		ur.community_fund_code1::text     AS CommunityFundCode1,
		ur.community_fund_code2::text     AS CommunityFundCode2,
		ur.commfund1_opted_in             AS CommFund1OptedIn,
		ur.commfund2_opted_in             AS CommFund2OptedIn,
		race_cs.description               AS Race,
		rel_cs.description                AS Religion,
		ctz_cs.description                AS Citizenship,
		ctz_cs.code                       AS CitizenshipCode,
		ui.date_of_birth                  AS DateOfBirth,

		-- SPR residency (drives CPF), matching times-employee-api EpmHelper.DeriveResidency:
		--   is_spr comes from user_identity.is_spr; the approved date from user_regulatory_spr.
		COALESCE(ui.is_spr, false)        AS IsSpr,
		spr.spr_approved_date::date       AS SprApprovedDate

	FROM security.user u
	LEFT JOIN employee.user_regulatory ur
		ON ur.user_id = u.id

	-- SPR details linked to the regulatory row (regulatory_id -> user_regulatory.id)
	LEFT JOIN employee.user_regulatory_spr spr
		ON spr.regulatory_id = ur.id

	LEFT JOIN security.user_identity ui
		ON ui.user_id = u.id
	LEFT JOIN company.code_setup race_cs
		ON race_cs.id = ui.race_id
		AND race_cs.code_setup_type_id = ui.race_type_id
	LEFT JOIN company.code_setup rel_cs
		ON rel_cs.id = ui.religion_id
		AND rel_cs.code_setup_type_id = ui.religion_type_id
	LEFT JOIN company.code_setup ctz_cs
		ON ctz_cs.id = ui.citizenship_id
		AND ctz_cs.code_setup_type_id = ui.citizenship_type_id

	-- employee-level payroll gate: company role status for this user
	LEFT JOIN LATERAL (
		SELECT ucr.user_role_status_id
		FROM   security.user_company_role ucr
		WHERE  ucr.user_id = u.id
		-- AND  ucr.company_id = p_companyid   -- re-enable alongside the company filter below
		LIMIT 1
	) ucr ON TRUE

	WHERE
		--companyid = p_companyid AND
		is_external = FALSE
		AND u.uid = ANY(p_user_uids)   -- process only the requested user UIDs

$$;


ALTER FUNCTION employee.get_employees_by_company_id(p_companyid integer, p_user_uids uuid[]) OWNER TO timesadmin;

--
-- TOC entry 983 (class 1255 OID 113536)
-- Name: get_payroll_cycle_by_id(integer); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.get_payroll_cycle_by_id(p_id integer) RETURNS TABLE(id integer, uid uuid, name text, code text)
    LANGUAGE sql STABLE
    AS $$
    SELECT c.id::integer,
           c.uid,
           c.name::text,
           c.code::text
    FROM payroll.lk_payroll_cycle c
    WHERE c.id = p_id
    LIMIT 1;
$$;


ALTER FUNCTION employee.get_payroll_cycle_by_id(p_id integer) OWNER TO timesadmin;

--
-- TOC entry 942 (class 1255 OID 89663)
-- Name: set_single_default_address(); Type: FUNCTION; Schema: employee; Owner: timesadmin
--

CREATE FUNCTION employee.set_single_default_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.is_default = TRUE THEN
        UPDATE employee.user_company_address
        SET is_default = FALSE
        WHERE user_id = NEW.user_id
          AND id <> NEW.id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION employee.set_single_default_address() OWNER TO timesadmin;

--
-- TOC entry 985 (class 1255 OID 107522)
-- Name: fn_pay_run_set_code(); Type: FUNCTION; Schema: payroll; Owner: timesadmin
--

CREATE FUNCTION payroll.fn_pay_run_set_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_short_code   text;
    v_period_value text;
    v_period_ym    text;
    v_prefix       text;
    v_next_no      integer;
BEGIN
    -- an explicitly supplied code wins (data migrations / corrections)
    IF NEW.code IS NOT NULL AND btrim(NEW.code) <> '' THEN
        RETURN NEW;
    END IF;

    SELECT c.short_code
      INTO v_short_code
      FROM payroll.lk_payroll_cycle c
     WHERE c.id = NEW.pay_cycle_id;

    IF v_short_code IS NULL OR btrim(v_short_code) = '' THEN
        RAISE EXCEPTION 'payroll.lk_payroll_cycle.short_code is not configured for pay_cycle_id %', NEW.pay_cycle_id;
    END IF;

    IF NEW.pay_period_id IS NULL THEN
        RAISE EXCEPTION 'pay_period_id is required to generate payroll.pay_run.code';
    END IF;

    SELECT btrim(p.value)
      INTO v_period_value
      FROM payroll.pay_period p
     WHERE p.id = NEW.pay_period_id;

    -- expected format: MM/YYYY (e.g. 08/2026); to_date() alone is too lenient to trust
    IF v_period_value IS NULL OR v_period_value !~ '^(0[1-9]|1[0-2])/[0-9]{4}$' THEN
        RAISE EXCEPTION 'payroll.pay_period.value "%" for pay_period_id % is missing or not in MM/YYYY format',
            v_period_value, NEW.pay_period_id;
    END IF;

    -- 'MM/YYYY' -> 'YYYY-MM'
    v_period_ym := split_part(v_period_value, '/', 2) || '-' || split_part(v_period_value, '/', 1);

    v_prefix := 'PR-' || v_short_code || '-' || v_period_ym;

    PERFORM pg_advisory_xact_lock(hashtext(v_prefix));

    SELECT COALESCE(MAX(split_part(r.code, '-', 5)::integer), 0) + 1
      INTO v_next_no
      FROM payroll.pay_run r
     WHERE r.code LIKE v_prefix || '-%'
       AND split_part(r.code, '-', 5) ~ '^[0-9]+$';

    -- lpad() truncates a value that is already wider than the pad length, so widen the
    -- pad instead of losing digits once a cycle/month goes past 999 runs
    NEW.code := v_prefix || '-' || lpad(v_next_no::text, GREATEST(3, length(v_next_no::text)), '0');

    RETURN NEW;
END;
$_$;


ALTER FUNCTION payroll.fn_pay_run_set_code() OWNER TO timesadmin;

--
-- TOC entry 987 (class 1255 OID 114250)
-- Name: get_pay_record_for_reprocess(uuid); Type: FUNCTION; Schema: payroll; Owner: timesadmin
--

CREATE FUNCTION payroll.get_pay_record_for_reprocess(p_pay_record_uid uuid) RETURNS TABLE(payrecorduid uuid, payrunid bigint, payrunuid uuid, payperioduid uuid, paycycleid integer, companyid integer, period text, userid integer, useruid uuid, contractid text, contractdbid bigint, contractuid uuid, statusid integer, basicsalary numeric, totalallowance numeric, totaldeduction numeric, totalcpf numeric, totalpayout numeric, dataprocessed text)
    LANGUAGE sql ROWS 1
    AS $$

    SELECT
        pr.uid                  AS payrecorduid,
        pr.pay_run_id           AS payrunid,
        run.uid                 AS payrunuid,       -- NEW
        pp.uid                  AS payperioduid,
        run.pay_cycle_id        AS paycycleid,
        c.company_id            AS companyid,
        pp.value                AS period,
        pr.user_id              AS userid,
        u.uid                   AS useruid,          -- NEW
        c.contract_id           AS contractid,
        pr.contract_id          AS contractdbid,
        c.uid                   AS contractuid,
        pr.status_id            AS statusid,
        pr.basic_salary         AS basicsalary,
        pr.total_allowance      AS totalallowance,
        pr.total_deduction      AS totaldeduction,
        pr.total_cpf            AS totalcpf,
        pr.total_payout         AS totalpayout,
        pr.data_processed::text AS dataprocessed
    FROM payroll.pay_record pr
    JOIN payroll.pay_run run                   ON run.id = pr.pay_run_id
    LEFT JOIN payroll.pay_period pp            ON pp.id  = run.pay_period_id
    LEFT JOIN employee.user_company_contract c ON c.id   = pr.contract_id
    LEFT JOIN security."user" u                ON u.id   = pr.user_id
    WHERE pr.uid = p_pay_record_uid
    LIMIT 1;

$$;


ALTER FUNCTION payroll.get_pay_record_for_reprocess(p_pay_record_uid uuid) OWNER TO timesadmin;

--
-- TOC entry 938 (class 1255 OID 80584)
-- Name: auto_set_full_name(); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.auto_set_full_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Build full_name safely (handles nulls)
    NEW.full_name :=
        trim(
            coalesce(NEW.first_name, '') || ' ' ||
            coalesce(NEW.last_name, '')
        );

    RETURN NEW;
END;
$$;


ALTER FUNCTION security.auto_set_full_name() OWNER TO timesadmin;

--
-- TOC entry 968 (class 1255 OID 69718)
-- Name: copy_user_full_access(integer, text, integer, text, integer[], text); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.copy_user_full_access(p_source_user_id integer, p_source_user_uid text, p_target_user_id integer, p_target_user_uid text, p_company_ids integer[], p_audit_user text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    rows_inserted INT;
    child_rec RECORD;
    new_id INT;
BEGIN
    ----------------------------------------------------------------------
    -- 0. Cleanup existing target data for these companies
    ----------------------------------------------------------------------
    DELETE FROM security.user_company_role_function
    WHERE user_id = p_target_user_id
      AND company_id = ANY(p_company_ids);

    DELETE FROM security.user_company_role
    WHERE user_id = p_target_user_id
      AND company_id = ANY(p_company_ids);

    DELETE FROM security.user_company
    WHERE user_id = p_target_user_id
      AND company_id = ANY(p_company_ids);

    DELETE FROM security.access_rules
    WHERE principle_type = 'user-company'
      AND user_id = p_target_user_id
      AND company_id = ANY(p_company_ids);

    ----------------------------------------------------------------------
    -- 1. Copy user_company
    ----------------------------------------------------------------------
    INSERT INTO security.user_company (
        user_id, company_id, designation, is_implicit,
        created_on, created_by, updated_on, updated_by
    )
    SELECT 
        p_target_user_id,
        uc.company_id,
        uc.designation, uc.is_implicit,
        now(), p_audit_user,
        now(), p_audit_user
    FROM security.user_company uc
    WHERE uc.user_id = p_source_user_id
      AND uc.company_id = ANY(p_company_ids);

    ----------------------------------------------------------------------
    -- 2. Copy user_company_role
    ----------------------------------------------------------------------
    INSERT INTO security.user_company_role (
        user_id, company_id, role_id, user_role_status_id,
        created_on, created_by, updated_on, updated_by
    )
    SELECT
        p_target_user_id,
        ucr.company_id,
        ucr.role_id,
        ucr.user_role_status_id,
        now(), p_audit_user,
        now(), p_audit_user
    FROM security.user_company_role ucr
    WHERE ucr.user_id = p_source_user_id
      AND ucr.company_id = ANY(p_company_ids);

    ----------------------------------------------------------------------
    -- 3. Copy user_company_role_function
    ----------------------------------------------------------------------
    INSERT INTO security.user_company_role_function (
        user_id, company_id, role_id, is_active,
        created_on, created_by, updated_on, updated_by
    )
    SELECT
        p_target_user_id,
        rf.company_id,
        rf.role_id,
        rf.is_active,
        now(), p_audit_user,
        now(), p_audit_user
    FROM security.user_company_role_function rf
    WHERE rf.user_id = p_source_user_id
      AND rf.company_id = ANY(p_company_ids);

    ----------------------------------------------------------------------
    -- 4. Copy access_rules hierarchically
    ----------------------------------------------------------------------
    
	DROP TABLE IF EXISTS tmp_access_map;
	CREATE TEMP TABLE tmp_access_map (
        old_id INT PRIMARY KEY,
        new_id INT
    ) ON COMMIT DROP;

    -- 4a. Insert root rules (parent_id IS NULL)
    FOR child_rec IN
        SELECT ar.*, c.uid AS company_uid
        FROM security.access_rules ar
        JOIN company.company c ON ar.company_id = c.id
        WHERE ar.principle_type = 'user-company'
          AND ar.user_id = p_source_user_id
          AND ar.company_id = ANY(p_company_ids)
          AND ar.parent_id IS NULL
    LOOP
        INSERT INTO security.access_rules (
            resource, resource_type, principle, principle_type,
            user_id, company_id, permission, parent_id,
            created_on, created_by, updated_on, updated_by,
            is_active, is_granted
        )
        VALUES (
            child_rec.resource,
            child_rec.resource_type,
            CONCAT(p_target_user_uid, '@', child_rec.company_uid),
            child_rec.principle_type,
            p_target_user_id,
            child_rec.company_id,
            child_rec.permission,
            NULL,
            now(), p_audit_user,
            now(), p_audit_user,
            child_rec.is_active,
            child_rec.is_granted
        )
        RETURNING id INTO new_id;

        INSERT INTO tmp_access_map(old_id, new_id)
        VALUES (child_rec.id, new_id);
    END LOOP;

    -- 4b. Iteratively insert children until done
    LOOP
        rows_inserted := 0;

        FOR child_rec IN
            SELECT ar.*, c.uid AS company_uid, m.new_id AS parent_new_id
            FROM security.access_rules ar
            JOIN tmp_access_map m ON ar.parent_id = m.old_id
            JOIN company.company c ON ar.company_id = c.id
            WHERE ar.principle_type = 'user-company'
              AND ar.user_id = p_source_user_id
              AND ar.company_id = ANY(p_company_ids)
              AND NOT EXISTS (
                    SELECT 1 FROM tmp_access_map x WHERE x.old_id = ar.id
              )
        LOOP
            INSERT INTO security.access_rules (
                resource, resource_type, principle, principle_type,
                user_id, company_id, permission, parent_id,
                created_on, created_by, updated_on, updated_by,
                is_active, is_granted
            )
            VALUES (
                child_rec.resource,
                child_rec.resource_type,
                CONCAT(p_target_user_uid, '@', child_rec.company_uid),
                child_rec.principle_type,
                p_target_user_id,
                child_rec.company_id,
                child_rec.permission,
                child_rec.parent_new_id,
                now(), p_audit_user,
                now(), p_audit_user,
                child_rec.is_active,
                child_rec.is_granted
            )
            RETURNING id INTO new_id;

            INSERT INTO tmp_access_map(old_id, new_id)
            VALUES (child_rec.id, new_id);

            rows_inserted := rows_inserted + 1;
        END LOOP;

        EXIT WHEN rows_inserted = 0;
    END LOOP;

END;
$$;


ALTER FUNCTION security.copy_user_full_access(p_source_user_id integer, p_source_user_uid text, p_target_user_id integer, p_target_user_uid text, p_company_ids integer[], p_audit_user text) OWNER TO timesadmin;

--
-- TOC entry 937 (class 1255 OID 78777)
-- Name: email_to_lowercase(); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.email_to_lowercase() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
    IF NEW.email IS NOT NULL THEN
        NEW.email := LOWER(NEW.email);
    END IF;
    RETURN NEW;
END;$$;


ALTER FUNCTION security.email_to_lowercase() OWNER TO timesadmin;

--
-- TOC entry 965 (class 1255 OID 52321)
-- Name: get_feature_and_field_permissions_for_principle(text); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.get_feature_and_field_permissions_for_principle(p_principle text) RETURNS TABLE(resource text, resource_type public.resource_type_enum, permission text, source text)
    LANGUAGE sql STABLE
    AS $$
WITH RECURSIVE permission_tree AS (
  -- Get feature-level rules
  SELECT
    ar.id,
    ar.resource,
    ar.resource_type,
    ar.permission,
    ar.principle,
    ar.principle_type,
    ar.parent_id,
    'feature-level' AS source
  FROM security.access_rules ar
  WHERE ar.resource_type = 'feature'
    AND ar.principle = p_principle

  UNION ALL

  -- Get field-level rules where parent_id points to a feature rule
  SELECT
    child.id,
    child.resource,
    child.resource_type,
    child.permission,
    child.principle,
    child.principle_type,
    child.parent_id,
    'field-level (via parent)' AS source
  FROM security.access_rules child
  JOIN permission_tree parent ON child.parent_id = parent.id
)
SELECT
  resource,
  resource_type,
  permission,
  source
FROM permission_tree
ORDER BY source, resource;
$$;


ALTER FUNCTION security.get_feature_and_field_permissions_for_principle(p_principle text) OWNER TO timesadmin;

--
-- TOC entry 964 (class 1255 OID 52320)
-- Name: get_permissions_for_principle_on_resource(text, public.resource_type_enum, text); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.get_permissions_for_principle_on_resource(p_resource text, p_resource_type public.resource_type_enum, p_principle text) RETURNS TABLE(resource text, resource_type public.resource_type_enum, permission text, source text)
    LANGUAGE sql STABLE
    AS $$
WITH RECURSIVE permission_tree AS (
  SELECT
    ar.id,
    ar.resource,
    ar.resource_type,
    ar.permission,
    ar.principle,
    ar.principle_type,
    ar.parent_id,
    'direct' AS source
  FROM security.access_rules ar
  WHERE
    ar.resource = p_resource
    AND ar.resource_type = p_resource_type
    AND ar.principle = p_principle

  UNION ALL

  SELECT
    parent.id,
    parent.resource,
    parent.resource_type,
    parent.permission,
    parent.principle,
    parent.principle_type,
    parent.parent_id,
    'inherited' AS source
  FROM security.access_rules parent
  JOIN permission_tree child ON parent.id = child.parent_id
)
SELECT
  resource,
  resource_type,
  permission,
  source
FROM permission_tree;
$$;


ALTER FUNCTION security.get_permissions_for_principle_on_resource(p_resource text, p_resource_type public.resource_type_enum, p_principle text) OWNER TO timesadmin;

--
-- TOC entry 966 (class 1255 OID 52948)
-- Name: get_permissions_for_principle_on_resource(text, public.resource_type_enum, text, uuid); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.get_permissions_for_principle_on_resource(p_resource text, p_resource_type public.resource_type_enum, p_principle text, p_company_id uuid) RETURNS TABLE(resource text, resource_type public.resource_type_enum, permission text, source text)
    LANGUAGE sql STABLE
    AS $$
WITH RECURSIVE permission_tree AS (
  -- base: the direct rules for the requested resource/principle
  SELECT
    ar.id,
    ar.resource,
    ar.resource_type,
    ar.permission,
    ar.principle,
    ar.principle_type,
    ar.parent_id,
    ar.is_active,
    ar.is_granted,
    ar.id AS root_id,                                   -- anchor id for this chain
    (ar.is_active AND ar.is_granted) AS all_active_and_granted,
    ARRAY[ar.id] AS path,                               -- used to prevent cycles
    'direct'::text AS source
  FROM security.access_rules ar
  WHERE ar.resource = p_resource
    AND ar.resource_type = p_resource_type
    AND ar.principle = p_principle

  UNION ALL

  -- recursive: walk up to parents, propagate the all_active_and_granted flag
  SELECT
    parent.id,
    parent.resource,
    parent.resource_type,
    parent.permission,
    parent.principle,
    parent.principle_type,
    parent.parent_id,
    parent.is_active,
    parent.is_granted,
    child.root_id,                                      -- keep same root_id
    (child.all_active_and_granted AND parent.is_active AND parent.is_granted) AS all_active_and_granted,
    child.path || parent.id,
    'inherited'::text
  FROM security.access_rules parent
  JOIN permission_tree child
    ON parent.id = child.parent_id
  WHERE NOT parent.id = ANY(child.path)                -- prevent cycles
)
, company_status AS (
  SELECT cs.name AS status
  FROM company.company c
  JOIN company.company_status cs ON cs.id = c.company_status_id
  WHERE c.uid = p_company_id
)
SELECT DISTINCT
  pt.resource,
  pt.resource_type,
  pt.permission,
  pt.source
FROM permission_tree pt
CROSS JOIN company_status cs
WHERE
  -- Include only those roots whose full chain up to the topmost ancestor is all active+granted.
  -- The topmost ancestor for a given root is the permission_tree row with the same root_id and parent_id IS NULL.
  EXISTS (
    SELECT 1
    FROM permission_tree top
    WHERE top.root_id = pt.root_id
      AND top.parent_id IS NULL
      AND top.all_active_and_granted = true
  )
  AND (
    cs.status != 'Inactive'
    OR (cs.status = 'Inactive' AND pt.permission = 'View')
  );
$$;


ALTER FUNCTION security.get_permissions_for_principle_on_resource(p_resource text, p_resource_type public.resource_type_enum, p_principle text, p_company_id uuid) OWNER TO timesadmin;

--
-- TOC entry 967 (class 1255 OID 65702)
-- Name: get_permissions_for_principle_under_function(text, text); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.get_permissions_for_principle_under_function(p_function_code text, p_principle text) RETURNS TABLE(resource text, resource_type public.resource_type_enum, permission text, source text)
    LANGUAGE sql
    AS $$
WITH RECURSIVE permission_tree AS (
    -- Start from the top-level function
    SELECT
        ar.id,
        ar.resource,
        ar.resource_type,
        ar.permission,
        ar.principle,
        ar.parent_id,
        'direct' AS source
    FROM security.access_rules ar
    WHERE ar.resource = p_function_code
      AND ar.principle = p_principle
      AND ar.is_active = TRUE
      AND ar.is_granted = TRUE

    UNION ALL

    -- Traverse downward (child permissions)
    SELECT
        child.id,
        child.resource,
        child.resource_type,
        child.permission,
        child.principle,
        child.parent_id,
        'inherited' AS source
    FROM security.access_rules child
    INNER JOIN permission_tree parent
        ON child.parent_id = parent.id
    WHERE child.is_active = TRUE
      AND child.is_granted = TRUE
      AND child.principle = p_principle
)
SELECT
    pt.resource,
    pt.resource_type,
    pt.permission,
    pt.source
FROM permission_tree pt
ORDER BY pt.resource;
$$;


ALTER FUNCTION security.get_permissions_for_principle_under_function(p_function_code text, p_principle text) OWNER TO timesadmin;

--
-- TOC entry 969 (class 1255 OID 81491)
-- Name: get_permissions_for_principle_under_function(text, text, uuid); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.get_permissions_for_principle_under_function(p_function_code text, p_principle text, p_company_id uuid) RETURNS TABLE(resource text, resource_type public.resource_type_enum, permission text, source text)
    LANGUAGE sql
    AS $$
WITH RECURSIVE permission_tree AS (
    -- Start from the top-level function
    SELECT
        ar.id,
        ar.resource,
        ar.resource_type,
        ar.permission,
        ar.principle,
        ar.parent_id,
        'direct'::text AS source
    FROM security.access_rules ar
    WHERE ar.resource = p_function_code
      AND ar.principle = p_principle
      AND ar.is_active = TRUE
      AND ar.is_granted = TRUE

    UNION ALL

    -- Traverse downward (child permissions)
    SELECT
        child.id,
        child.resource,
        child.resource_type,
        child.permission,
        child.principle,
        child.parent_id,
        'inherited'::text AS source
    FROM security.access_rules child
    INNER JOIN permission_tree parent
        ON child.parent_id = parent.id
    WHERE child.is_active = TRUE
      AND child.is_granted = TRUE
      AND child.principle = p_principle
),
company_status AS (
  SELECT cs.name AS status
  FROM company.company c
  JOIN company.company_status cs ON cs.id = c.company_status_id
  WHERE c.uid = p_company_id
)
SELECT
    pt.resource,
    pt.resource_type,
    pt.permission,
    pt.source
FROM permission_tree pt
CROSS JOIN company_status cs
WHERE
    cs.status <> 'Inactive'
    OR (cs.status = 'Inactive' AND pt.permission = 'View')
ORDER BY pt.resource;
$$;


ALTER FUNCTION security.get_permissions_for_principle_under_function(p_function_code text, p_principle text, p_company_id uuid) OWNER TO timesadmin;

--
-- TOC entry 939 (class 1255 OID 84204)
-- Name: set_single_default_address(); Type: FUNCTION; Schema: security; Owner: timesadmin
--

CREATE FUNCTION security.set_single_default_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Only run if the new record has is_default = true
    IF NEW.is_default = TRUE THEN
        UPDATE security.user_company_address
        SET is_default = FALSE
        WHERE user_id = NEW.user_id
          AND company_id = NEW.company_id
          AND id <> NEW.id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION security.set_single_default_address() OWNER TO timesadmin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 662 (class 1259 OID 64886)
-- Name: absent_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.absent_code (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    absent_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    cpf_id bigint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.absent_code OWNER TO timesadmin;

--
-- TOC entry 661 (class 1259 OID 64885)
-- Name: absent_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.absent_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.absent_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 603 (class 1259 OID 60731)
-- Name: allowance_deduction; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    year integer DEFAULT EXTRACT(year FROM CURRENT_DATE) NOT NULL,
    company_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    tax_id bigint NOT NULL,
    cpf_id bigint NOT NULL,
    type_id bigint NOT NULL,
    bonus_type_id bigint NOT NULL,
    gross_wage_id bigint,
    backpay_allowance_id bigint,
    unit_id bigint,
    grp_formula_id bigint,
    custom_report_group_code text,
    payslip_group_code text,
    alert_deduction_resigned_employee boolean DEFAULT true NOT NULL,
    sdf boolean DEFAULT false,
    nsp boolean DEFAULT false,
    community_funds boolean DEFAULT false,
    mso boolean DEFAULT true,
    "union" boolean DEFAULT false,
    ot boolean DEFAULT false,
    npl boolean DEFAULT false,
    grp boolean DEFAULT false,
    rd boolean DEFAULT false,
    non_payroll_item boolean DEFAULT false,
    oed_gross_wage boolean DEFAULT false,
    benefit_in_kind_id bigint,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text DEFAULT 'Admin'::text NOT NULL,
    is_active boolean DEFAULT true,
    gl_default_identifier text,
    service_point boolean DEFAULT false
);


ALTER TABLE company.allowance_deduction OWNER TO timesadmin;

--
-- TOC entry 595 (class 1259 OID 60672)
-- Name: allowance_deduction_back_pay_allowance; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_back_pay_allowance (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.allowance_deduction_back_pay_allowance OWNER TO timesadmin;

--
-- TOC entry 594 (class 1259 OID 60671)
-- Name: allowance_deduction_back_pay_allowance_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_back_pay_allowance ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_back_pay_allowance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 601 (class 1259 OID 60714)
-- Name: allowance_deduction_benefit_in_kind; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_benefit_in_kind (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.allowance_deduction_benefit_in_kind OWNER TO timesadmin;

--
-- TOC entry 600 (class 1259 OID 60713)
-- Name: allowance_deduction_benefit_in_kind_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_benefit_in_kind ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_benefit_in_kind_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 591 (class 1259 OID 60644)
-- Name: allowance_deduction_bonus_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_bonus_type (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.allowance_deduction_bonus_type OWNER TO timesadmin;

--
-- TOC entry 590 (class 1259 OID 60643)
-- Name: allowance_deduction_bonus_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_bonus_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_bonus_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 587 (class 1259 OID 60616)
-- Name: allowance_deduction_cpf; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_cpf (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE company.allowance_deduction_cpf OWNER TO timesadmin;

--
-- TOC entry 586 (class 1259 OID 60615)
-- Name: allowance_deduction_cpf_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_cpf ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_cpf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 593 (class 1259 OID 60658)
-- Name: allowance_deduction_gross_wage; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_gross_wage (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.allowance_deduction_gross_wage OWNER TO timesadmin;

--
-- TOC entry 592 (class 1259 OID 60657)
-- Name: allowance_deduction_gross_wage_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_gross_wage ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_gross_wage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 599 (class 1259 OID 60700)
-- Name: allowance_deduction_grp_formula; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_grp_formula (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.allowance_deduction_grp_formula OWNER TO timesadmin;

--
-- TOC entry 598 (class 1259 OID 60699)
-- Name: allowance_deduction_grp_formula_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_grp_formula ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_grp_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 602 (class 1259 OID 60730)
-- Name: allowance_deduction_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 585 (class 1259 OID 60602)
-- Name: allowance_deduction_tax; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_tax (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE company.allowance_deduction_tax OWNER TO timesadmin;

--
-- TOC entry 584 (class 1259 OID 60601)
-- Name: allowance_deduction_tax_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_tax ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_tax_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 589 (class 1259 OID 60630)
-- Name: allowance_deduction_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_type (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.allowance_deduction_type OWNER TO timesadmin;

--
-- TOC entry 588 (class 1259 OID 60629)
-- Name: allowance_deduction_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 597 (class 1259 OID 60686)
-- Name: allowance_deduction_unit; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.allowance_deduction_unit (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.allowance_deduction_unit OWNER TO timesadmin;

--
-- TOC entry 596 (class 1259 OID 60685)
-- Name: allowance_deduction_unit_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.allowance_deduction_unit ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.allowance_deduction_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 437 (class 1259 OID 35525)
-- Name: area; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.area (
    id integer NOT NULL,
    name text NOT NULL,
    uid uuid NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE company.area OWNER TO timesadmin;

--
-- TOC entry 436 (class 1259 OID 35524)
-- Name: area_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.area ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.area_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 875 (class 1259 OID 97806)
-- Name: asset_management_log; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.asset_management_log (
    id bigint NOT NULL,
    asset_id bigint NOT NULL,
    remarks text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    action_date timestamp without time zone,
    log_action_id bigint,
    target_user text
);


ALTER TABLE company.asset_management_log OWNER TO timesadmin;

--
-- TOC entry 874 (class 1259 OID 97805)
-- Name: asset_management_log_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.asset_management_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.asset_management_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 440 (class 1259 OID 35553)
-- Name: bank; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.bank (
    id integer NOT NULL,
    bank_code character varying(8) NOT NULL,
    bank_category_id bigint DEFAULT 1 NOT NULL,
    bank_name text NOT NULL,
    swift_code text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50) DEFAULT 'Admin'::character varying NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    area_id bigint DEFAULT 1 NOT NULL,
    logo_url text,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE company.bank OWNER TO timesadmin;

--
-- TOC entry 441 (class 1259 OID 35569)
-- Name: bank_branch; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.bank_branch (
    id bigint NOT NULL,
    code character varying(5) NOT NULL,
    name text NOT NULL,
    bank_id integer NOT NULL,
    address1 text,
    address2 text,
    postal_code text,
    bank_officer text,
    phone_number character varying(20),
    fax_number character varying(20),
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50) DEFAULT 'Admin'::character varying NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    city text
);


ALTER TABLE company.bank_branch OWNER TO timesadmin;

--
-- TOC entry 519 (class 1259 OID 48463)
-- Name: bank_branch_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.bank_branch ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.bank_branch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 439 (class 1259 OID 35544)
-- Name: bank_category; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.bank_category (
    id integer NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL
);


ALTER TABLE company.bank_category OWNER TO timesadmin;

--
-- TOC entry 438 (class 1259 OID 35543)
-- Name: bank_category_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.bank_category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.bank_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 518 (class 1259 OID 48447)
-- Name: bank_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.bank ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.bank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 821 (class 1259 OID 93531)
-- Name: bank_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.bank_type (
    id smallint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.bank_type OWNER TO timesadmin;

--
-- TOC entry 727 (class 1259 OID 75614)
-- Name: claim_financial_period; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.claim_financial_period (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    year text NOT NULL,
    company_id bigint NOT NULL,
    start_month integer DEFAULT 1 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT claim_financial_period_start_month_check CHECK (((start_month >= 1) AND (start_month <= 12)))
);


ALTER TABLE company.claim_financial_period OWNER TO timesadmin;

--
-- TOC entry 726 (class 1259 OID 75613)
-- Name: claim_financial_period_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.claim_financial_period ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.claim_financial_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 579 (class 1259 OID 56876)
-- Name: code_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.code_setup (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    code_setup_type_id bigint NOT NULL,
    relation_type_id bigint,
    code text NOT NULL,
    description text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    sort integer NOT NULL,
    occupation_group_id bigint,
    highest_education_attained_id bigint,
    occupation_category_id bigint,
    oed_map_code_id bigint,
    country_id bigint
);


ALTER TABLE company.code_setup OWNER TO timesadmin;

--
-- TOC entry 605 (class 1259 OID 60949)
-- Name: code_setup_category; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.code_setup_category (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.code_setup_category OWNER TO timesadmin;

--
-- TOC entry 604 (class 1259 OID 60948)
-- Name: code_setup_category_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.code_setup_category ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.code_setup_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 578 (class 1259 OID 56875)
-- Name: code_setup_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.code_setup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.code_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 577 (class 1259 OID 56866)
-- Name: code_setup_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.code_setup_type (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    code text NOT NULL,
    code_setup_category_id bigint DEFAULT 1 NOT NULL
);


ALTER TABLE company.code_setup_type OWNER TO timesadmin;

--
-- TOC entry 576 (class 1259 OID 56865)
-- Name: code_setup_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.code_setup_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.code_setup_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 452 (class 1259 OID 36366)
-- Name: company; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company (
    id integer NOT NULL,
    parent_company_id integer,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50),
    name text NOT NULL,
    area_id bigint,
    industry_id bigint,
    subscription_uid uuid NOT NULL,
    uen text NOT NULL,
    company_logo text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    address text,
    company_address_info_id bigint,
    sort integer DEFAULT 0 NOT NULL,
    company_status_id bigint DEFAULT 1 NOT NULL,
    is_self_defined boolean DEFAULT true NOT NULL,
    auto_number bigint DEFAULT 1 NOT NULL,
    custom_profile_regex text,
    regex_json jsonb,
    global_code_linked boolean DEFAULT false NOT NULL,
    personalization_code_linked boolean DEFAULT false NOT NULL,
    pay_code_linked boolean DEFAULT false NOT NULL,
    company_country_name text DEFAULT 'Singapore'::text NOT NULL,
    is_sg boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    banner_logo text
);


ALTER TABLE company.company OWNER TO timesadmin;

--
-- TOC entry 660 (class 1259 OID 64868)
-- Name: company_absent; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_absent (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    daily_rate_id bigint DEFAULT 8 NOT NULL,
    rounding_method_id bigint DEFAULT 2 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_absent OWNER TO timesadmin;

--
-- TOC entry 659 (class 1259 OID 64867)
-- Name: company_absent_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_absent ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_absent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 491 (class 1259 OID 37102)
-- Name: company_address_info_kiv; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_address_info_kiv (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    address text NOT NULL,
    country_city_id bigint,
    country_state_id bigint,
    postal_code character varying(8),
    country_id bigint,
    created_on timestamp without time zone DEFAULT now(),
    created_by text DEFAULT 'system'::text,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_address_info_kiv OWNER TO timesadmin;

--
-- TOC entry 866 (class 1259 OID 95651)
-- Name: company_asset; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_asset (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    photo text,
    description text NOT NULL,
    asset_status_id bigint NOT NULL,
    serial_no text,
    asset_type_id bigint NOT NULL,
    asset_type_type_id integer GENERATED ALWAYS AS (83) STORED NOT NULL,
    specification text NOT NULL,
    purchase_date timestamp without time zone,
    warranty_expiry timestamp without time zone,
    currency_code_id bigint,
    price numeric,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    currency_code_type_id integer GENERATED ALWAYS AS (9) STORED,
    asset_id text NOT NULL
);


ALTER TABLE company.company_asset OWNER TO timesadmin;

--
-- TOC entry 865 (class 1259 OID 95650)
-- Name: company_asset_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_asset ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_asset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 458 (class 1259 OID 36468)
-- Name: company_bank; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_bank (
    id integer NOT NULL,
    bank_id bigint NOT NULL,
    payment_profile_id bigint NOT NULL,
    payment_type_id bigint NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    bank_branch_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    account_number bytea
);


ALTER TABLE company.company_bank OWNER TO timesadmin;

--
-- TOC entry 457 (class 1259 OID 36467)
-- Name: company_bank_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_bank ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.company_bank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 460 (class 1259 OID 36511)
-- Name: company_contact_info; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_contact_info (
    id integer NOT NULL,
    company_id integer NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(150) NOT NULL,
    designation character varying(100),
    contact_number character varying(20),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by text,
    updated_on timestamp without time zone,
    updated_by text,
    type text DEFAULT 'main'::text NOT NULL,
    contact_country_code text
);


ALTER TABLE company.company_contact_info OWNER TO timesadmin;

--
-- TOC entry 459 (class 1259 OID 36510)
-- Name: company_contact_info_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_contact_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.company_contact_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 567 (class 1259 OID 55870)
-- Name: company_employment_setting; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_employment_setting (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    hired_age integer DEFAULT 18 NOT NULL,
    retired_age integer DEFAULT 63 NOT NULL,
    probation_period integer DEFAULT 3,
    probation_period_type_id bigint DEFAULT 1,
    notice_period integer DEFAULT 0,
    notice_period_type_id bigint DEFAULT 1,
    retention_period integer DEFAULT 5 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_employment_setting OWNER TO timesadmin;

--
-- TOC entry 566 (class 1259 OID 55869)
-- Name: company_employment_setting_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_employment_setting ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_employment_setting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 451 (class 1259 OID 36365)
-- Name: company_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.company_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 462 (class 1259 OID 36527)
-- Name: company_layout; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_layout (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    user_id bigint DEFAULT 1 NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    content_json json NOT NULL
);


ALTER TABLE company.company_layout OWNER TO timesadmin;

--
-- TOC entry 461 (class 1259 OID 36526)
-- Name: company_layout_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_layout ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_layout_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 803 (class 1259 OID 90884)
-- Name: company_levy_management; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_levy_management (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    work_pass_id bigint NOT NULL,
    work_pass_type_id integer GENERATED ALWAYS AS (59) STORED NOT NULL,
    sector_id bigint NOT NULL,
    sector_type_id integer GENERATED ALWAYS AS (60) STORED NOT NULL,
    levy_method_id bigint NOT NULL,
    tier_id bigint NOT NULL,
    tier_type_id integer GENERATED ALWAYS AS (61) STORED NOT NULL,
    quota_id bigint NOT NULL,
    quota_type_id integer GENERATED ALWAYS AS (62) STORED NOT NULL,
    effective_year integer DEFAULT (EXTRACT(year FROM CURRENT_DATE))::integer NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    area_id bigint DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE company.company_levy_management OWNER TO timesadmin;

--
-- TOC entry 802 (class 1259 OID 90883)
-- Name: company_levy_management_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_levy_management ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_levy_management_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 681 (class 1259 OID 67416)
-- Name: company_nsp_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_nsp_setup (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    nsp_formula_id bigint DEFAULT 1 NOT NULL,
    nsp_deduction_code_id bigint NOT NULL,
    is_overtime boolean DEFAULT false NOT NULL,
    is_shift boolean DEFAULT false NOT NULL,
    is_rest_day boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_nsp_setup OWNER TO timesadmin;

--
-- TOC entry 680 (class 1259 OID 67415)
-- Name: company_nsp_setup_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_nsp_setup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_nsp_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 563 (class 1259 OID 55843)
-- Name: company_organization_structure; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_organization_structure (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    organization_chart jsonb,
    organization_hierarchy jsonb DEFAULT '{"Team": 0, "Unit": 0, "Company": 1, "Section": 4, "Division": 2, "Department": 3}'::jsonb NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_organization_structure OWNER TO timesadmin;

--
-- TOC entry 562 (class 1259 OID 55842)
-- Name: company_organization_structure_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_organization_structure ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_organization_structure_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 693 (class 1259 OID 73648)
-- Name: company_ot_capping; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_ot_capping (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    ot_ceiling_type_id bigint DEFAULT 1 NOT NULL,
    ot_ceiling_min numeric DEFAULT 0.00,
    ot_ceiling_max numeric DEFAULT 2250,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_ot_capping OWNER TO timesadmin;

--
-- TOC entry 692 (class 1259 OID 73647)
-- Name: company_ot_capping_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_ot_capping ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_ot_capping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 650 (class 1259 OID 63682)
-- Name: company_ot_rate; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_ot_rate (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_overtime boolean DEFAULT true NOT NULL,
    ot_rate_formula_id bigint DEFAULT 4 NOT NULL,
    ot_ceiling_type_id bigint DEFAULT 1 NOT NULL,
    rounding_method_id bigint DEFAULT 1 NOT NULL,
    min_ot_amount_ceiling numeric,
    max_ot_amount_ceiling numeric DEFAULT 2250,
    ot_hours_ceiling numeric DEFAULT 72 NOT NULL,
    ot_rate_setting_id bigint DEFAULT 2 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_ot_rate OWNER TO timesadmin;

--
-- TOC entry 649 (class 1259 OID 63681)
-- Name: company_ot_rate_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_ot_rate ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_ot_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 656 (class 1259 OID 64757)
-- Name: company_public_holiday; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_public_holiday (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    daily_rate_id bigint DEFAULT 11 NOT NULL,
    rounding_method_id bigint DEFAULT 1 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_public_holiday OWNER TO timesadmin;

--
-- TOC entry 655 (class 1259 OID 64756)
-- Name: company_public_holiday_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_public_holiday ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_public_holiday_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 630 (class 1259 OID 62380)
-- Name: company_rate_formula; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_rate_formula (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    daily_rate_id bigint DEFAULT 10 NOT NULL,
    hours_worked_per_year integer DEFAULT 2288 NOT NULL,
    hr1 numeric DEFAULT 8.00 NOT NULL,
    hr2 numeric DEFAULT 8.00 NOT NULL,
    hr3 numeric DEFAULT 8.00 NOT NULL,
    hr4 numeric DEFAULT 8.00 NOT NULL,
    hr5 numeric DEFAULT 8.00 NOT NULL,
    d1 numeric DEFAULT 8.00 NOT NULL,
    d2 numeric DEFAULT 8.00 NOT NULL,
    d3 numeric DEFAULT 8.00 NOT NULL,
    d4 numeric DEFAULT 8.00 NOT NULL,
    d5 numeric DEFAULT 8.00 NOT NULL,
    d6 numeric DEFAULT 8.00 NOT NULL,
    d7 numeric DEFAULT 8.00 NOT NULL,
    d8 numeric DEFAULT 8.00 NOT NULL,
    sn numeric DEFAULT 8.00 NOT NULL,
    se numeric DEFAULT 8.00 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_rate_formula OWNER TO timesadmin;

--
-- TOC entry 629 (class 1259 OID 62379)
-- Name: company_rate_formula_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_rate_formula ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_rate_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 636 (class 1259 OID 62676)
-- Name: company_rest_day; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_rest_day (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    daily_rate_id bigint DEFAULT 11 NOT NULL,
    rounding_method_id bigint DEFAULT 1 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_rest_day OWNER TO timesadmin;

--
-- TOC entry 635 (class 1259 OID 62675)
-- Name: company_rest_day_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_rest_day ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_rest_day_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 666 (class 1259 OID 64963)
-- Name: company_shift_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_shift_setup (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    average_shift_month_id bigint DEFAULT 1 NOT NULL,
    rounding_method_id bigint DEFAULT 2 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.company_shift_setup OWNER TO timesadmin;

--
-- TOC entry 665 (class 1259 OID 64962)
-- Name: company_shift_setup_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_shift_setup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_shift_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 450 (class 1259 OID 36278)
-- Name: company_status; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_status (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.company_status OWNER TO timesadmin;

--
-- TOC entry 449 (class 1259 OID 36277)
-- Name: company_status_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_status ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 464 (class 1259 OID 36571)
-- Name: company_statutory; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.company_statutory (
    id integer NOT NULL,
    company_id integer NOT NULL,
    statutory_id integer NOT NULL,
    effective_date timestamp without time zone,
    account_number character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE company.company_statutory OWNER TO timesadmin;

--
-- TOC entry 463 (class 1259 OID 36570)
-- Name: company_statutory_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.company_statutory ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.company_statutory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 446 (class 1259 OID 36238)
-- Name: country; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.country (
    id bigint NOT NULL,
    name text,
    iso3 text,
    iso2 text,
    numeric_code text,
    phone_code text,
    capital text,
    currency text,
    currency_name text,
    currency_symbol text,
    region text,
    region_id bigint,
    subregion text,
    subregion_id bigint,
    nationality text,
    created_on timestamp without time zone,
    created_by text,
    updated_on timestamp without time zone,
    updated_by text,
    is_enabled boolean DEFAULT false
);


ALTER TABLE company.country OWNER TO timesadmin;

--
-- TOC entry 448 (class 1259 OID 36259)
-- Name: country_city; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.country_city (
    id bigint NOT NULL,
    name text NOT NULL,
    country_state_id bigint,
    country_id bigint,
    created_on timestamp without time zone,
    created_by text,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.country_city OWNER TO timesadmin;

--
-- TOC entry 447 (class 1259 OID 36247)
-- Name: country_state; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.country_state (
    id bigint NOT NULL,
    name text NOT NULL,
    code text,
    country_id bigint,
    created_on timestamp without time zone,
    created_by text,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.country_state OWNER TO timesadmin;

--
-- TOC entry 466 (class 1259 OID 36575)
-- Name: cpf_account; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.cpf_account (
    id integer NOT NULL,
    company_bank_id bigint NOT NULL,
    cpf_number character varying(15) NOT NULL,
    voluntary_suffix character varying(5) NOT NULL,
    voluntary_account_number character varying(20) NOT NULL,
    income_tax_number character varying(10) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE company.cpf_account OWNER TO timesadmin;

--
-- TOC entry 465 (class 1259 OID 36574)
-- Name: cpf_account_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.cpf_account ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.cpf_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 711 (class 1259 OID 73827)
-- Name: customize_rest_day_grouping; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.customize_rest_day_grouping (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    employment_classification_id bigint,
    rd_ceiling_id bigint NOT NULL,
    rd_ceiling_min numeric(18,2) NOT NULL,
    rd_ceiling_max numeric(18,2) NOT NULL,
    fix_rate numeric(18,2),
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.customize_rest_day_grouping OWNER TO timesadmin;

--
-- TOC entry 710 (class 1259 OID 73826)
-- Name: customize_rest_day_grouping_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.customize_rest_day_grouping ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.customize_rest_day_grouping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 909 (class 1259 OID 104415)
-- Name: default_queries; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.default_queries (
    id bigint NOT NULL,
    uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    module_id integer NOT NULL,
    name character varying(255) NOT NULL,
    rules jsonb NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    updated_on timestamp without time zone,
    updated_by character varying(255)
);


ALTER TABLE company.default_queries OWNER TO timesadmin;

--
-- TOC entry 908 (class 1259 OID 104414)
-- Name: default_queries_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.default_queries ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.default_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 468 (class 1259 OID 36598)
-- Name: document_category; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.document_category (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by text,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.document_category OWNER TO timesadmin;

--
-- TOC entry 467 (class 1259 OID 36597)
-- Name: document_category_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.document_category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.document_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 930 (class 1259 OID 112744)
-- Name: document_favourite; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.document_favourite (
    user_id integer NOT NULL,
    document_id bigint NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE company.document_favourite OWNER TO timesadmin;

--
-- TOC entry 470 (class 1259 OID 36608)
-- Name: documents; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.documents (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name text,
    url text,
    document_category_id bigint,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    sort integer NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    type text DEFAULT 'Doc'::text NOT NULL,
    description text,
    file_name text,
    tags text[] DEFAULT '{}'::text[] NOT NULL
);


ALTER TABLE company.documents OWNER TO timesadmin;

--
-- TOC entry 469 (class 1259 OID 36607)
-- Name: documents_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.documents ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 654 (class 1259 OID 63748)
-- Name: encashment_method; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.encashment_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.encashment_method OWNER TO timesadmin;

--
-- TOC entry 653 (class 1259 OID 63747)
-- Name: encashment_method_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.encashment_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.encashment_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 733 (class 1259 OID 75662)
-- Name: formula_setup_settings; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.formula_setup_settings (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    prorate_new_hired boolean DEFAULT true NOT NULL,
    prorate_salary_formula_id bigint DEFAULT 10 NOT NULL,
    formula_setup_method_id bigint DEFAULT 2 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.formula_setup_settings OWNER TO timesadmin;

--
-- TOC entry 732 (class 1259 OID 75661)
-- Name: formula_setup_settings_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.formula_setup_settings ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.formula_setup_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 472 (class 1259 OID 36632)
-- Name: id_provident_fund; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.id_provident_fund (
    id bigint NOT NULL,
    company_bank_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    bpjs_number text NOT NULL,
    tax_submission_location text NOT NULL,
    company_npwp_number text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.id_provident_fund OWNER TO timesadmin;

--
-- TOC entry 471 (class 1259 OID 36631)
-- Name: id_provident_fund_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.id_provident_fund ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.id_provident_fund_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 474 (class 1259 OID 36648)
-- Name: id_tax_refund_calculation; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.id_tax_refund_calculation (
    id bigint NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE company.id_tax_refund_calculation OWNER TO timesadmin;

--
-- TOC entry 473 (class 1259 OID 36647)
-- Name: id_tax_refund_calculation_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.id_tax_refund_calculation ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.id_tax_refund_calculation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 478 (class 1259 OID 36682)
-- Name: id_tax_requirement; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.id_tax_requirement (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    tax_refund_calculation_id bigint NOT NULL,
    income_tax_wage_id bigint NOT NULL,
    jkk_jht_jkm_wage_id bigint NOT NULL,
    job_title_wage_id bigint NOT NULL,
    no_jht_ee boolean DEFAULT false NOT NULL,
    tax_adjustment boolean DEFAULT false NOT NULL,
    prorate_tax_amount boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.id_tax_requirement OWNER TO timesadmin;

--
-- TOC entry 477 (class 1259 OID 36681)
-- Name: id_tax_requirement_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.id_tax_requirement ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.id_tax_requirement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 476 (class 1259 OID 36672)
-- Name: id_wage_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.id_wage_type (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE company.id_wage_type OWNER TO timesadmin;

--
-- TOC entry 475 (class 1259 OID 36671)
-- Name: id_wage_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.id_wage_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.id_wage_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 445 (class 1259 OID 36222)
-- Name: industry; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.industry (
    id integer NOT NULL,
    name text NOT NULL,
    uid uuid NOT NULL,
    industry_group_id integer NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE company.industry OWNER TO timesadmin;

--
-- TOC entry 443 (class 1259 OID 36213)
-- Name: industry_group; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.industry_group (
    id integer NOT NULL,
    name text NOT NULL,
    uid uuid NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE company.industry_group OWNER TO timesadmin;

--
-- TOC entry 442 (class 1259 OID 36212)
-- Name: industry_group_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.industry_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.industry_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 444 (class 1259 OID 36221)
-- Name: industry_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.industry ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.industry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 725 (class 1259 OID 75593)
-- Name: leave_financial_period; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.leave_financial_period (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    year text NOT NULL,
    company_id bigint NOT NULL,
    start_month integer DEFAULT 1 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT leave_financial_period_start_month_check CHECK (((start_month >= 1) AND (start_month <= 12)))
);


ALTER TABLE company.leave_financial_period OWNER TO timesadmin;

--
-- TOC entry 724 (class 1259 OID 75592)
-- Name: leave_financial_period_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.leave_financial_period ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.leave_financial_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 805 (class 1259 OID 90932)
-- Name: levy_management_pay_period; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.levy_management_pay_period (
    id bigint NOT NULL,
    levy_management_id bigint NOT NULL,
    jan_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    jan_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    feb_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    feb_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    mar_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    mar_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    apr_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    apr_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    may_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    may_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    jun_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    jun_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    jul_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    jul_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    aug_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    aug_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    sep_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    sep_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    oct_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    oct_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    nov_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    nov_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    dec_month numeric(18,2) DEFAULT 0.00 NOT NULL,
    dec_day numeric(18,2) DEFAULT 0.00 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.levy_management_pay_period OWNER TO timesadmin;

--
-- TOC entry 804 (class 1259 OID 90931)
-- Name: levy_management_pay_period_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.levy_management_pay_period ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.levy_management_pay_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 751 (class 1259 OID 78288)
-- Name: lk_age_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_age_type (
    id bigint NOT NULL,
    age_from integer NOT NULL,
    age_to integer NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    code text DEFAULT 'Y0T35'::text NOT NULL
);


ALTER TABLE company.lk_age_type OWNER TO timesadmin;

--
-- TOC entry 750 (class 1259 OID 78287)
-- Name: lk_age_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_age_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_age_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 871 (class 1259 OID 97431)
-- Name: lk_asset_management_log_action; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_asset_management_log_action (
    id bigint NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_asset_management_log_action OWNER TO timesadmin;

--
-- TOC entry 870 (class 1259 OID 97430)
-- Name: lk_asset_management_log_action_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_asset_management_log_action ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_asset_management_log_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 864 (class 1259 OID 95640)
-- Name: lk_asset_status; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_asset_status (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_asset_status OWNER TO timesadmin;

--
-- TOC entry 863 (class 1259 OID 95639)
-- Name: lk_asset_status_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_asset_status ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_asset_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 664 (class 1259 OID 64952)
-- Name: lk_average_shift_month; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_average_shift_month (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_average_shift_month OWNER TO timesadmin;

--
-- TOC entry 663 (class 1259 OID 64951)
-- Name: lk_average_shift_month_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_average_shift_month ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_average_shift_month_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 745 (class 1259 OID 78099)
-- Name: lk_community_fund_category; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_community_fund_category (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_community_fund_category OWNER TO timesadmin;

--
-- TOC entry 744 (class 1259 OID 78098)
-- Name: lk_community_fund_category_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_community_fund_category ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_community_fund_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 612 (class 1259 OID 62124)
-- Name: lk_daily_rate; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_daily_rate (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    formula text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_daily_rate OWNER TO timesadmin;

--
-- TOC entry 674 (class 1259 OID 65866)
-- Name: lk_daily_rate_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_daily_rate ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_daily_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 743 (class 1259 OID 78088)
-- Name: lk_donation_category; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_donation_category (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_donation_category OWNER TO timesadmin;

--
-- TOC entry 742 (class 1259 OID 78087)
-- Name: lk_donation_category_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_donation_category ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_donation_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 668 (class 1259 OID 65026)
-- Name: lk_duration_unit; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_duration_unit (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_duration_unit OWNER TO timesadmin;

--
-- TOC entry 667 (class 1259 OID 65025)
-- Name: lk_duration_unit_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_duration_unit ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_duration_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 731 (class 1259 OID 75649)
-- Name: lk_formula_setup_method; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_formula_setup_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_formula_setup_method OWNER TO timesadmin;

--
-- TOC entry 730 (class 1259 OID 75648)
-- Name: lk_formula_setup_method_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_formula_setup_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_formula_setup_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 801 (class 1259 OID 90873)
-- Name: lk_levy_method; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_levy_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    code text
);


ALTER TABLE company.lk_levy_method OWNER TO timesadmin;

--
-- TOC entry 800 (class 1259 OID 90872)
-- Name: lk_levy_method_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_levy_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_levy_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 679 (class 1259 OID 67404)
-- Name: lk_nsp_formula; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_nsp_formula (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_nsp_formula OWNER TO timesadmin;

--
-- TOC entry 678 (class 1259 OID 67403)
-- Name: lk_nsp_formula_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_nsp_formula ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_nsp_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 691 (class 1259 OID 73619)
-- Name: lk_ot_ceiling_method; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_ot_ceiling_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_ot_ceiling_method OWNER TO timesadmin;

--
-- TOC entry 690 (class 1259 OID 73618)
-- Name: lk_ot_ceiling_method_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_ot_ceiling_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_ot_ceiling_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 644 (class 1259 OID 63643)
-- Name: lk_ot_ceiling_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_ot_ceiling_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_ot_ceiling_type OWNER TO timesadmin;

--
-- TOC entry 643 (class 1259 OID 63642)
-- Name: lk_ot_ceiling_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_ot_ceiling_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_ot_ceiling_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 646 (class 1259 OID 63654)
-- Name: lk_ot_rate_formula; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_ot_rate_formula (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_ot_rate_formula OWNER TO timesadmin;

--
-- TOC entry 645 (class 1259 OID 63653)
-- Name: lk_ot_rate_formula_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_ot_rate_formula ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_ot_rate_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 648 (class 1259 OID 63665)
-- Name: lk_ot_rate_setting; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_ot_rate_setting (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_ot_rate_setting OWNER TO timesadmin;

--
-- TOC entry 647 (class 1259 OID 63664)
-- Name: lk_ot_rate_setting_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_ot_rate_setting ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_ot_rate_setting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 695 (class 1259 OID 73678)
-- Name: lk_prorate_formula; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_prorate_formula (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_prorate_formula OWNER TO timesadmin;

--
-- TOC entry 694 (class 1259 OID 73677)
-- Name: lk_prorate_formula_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_prorate_formula ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_prorate_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 729 (class 1259 OID 75636)
-- Name: lk_prorate_salary_formula; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_prorate_salary_formula (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_prorate_salary_formula OWNER TO timesadmin;

--
-- TOC entry 728 (class 1259 OID 75635)
-- Name: lk_prorate_salary_formula_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_prorate_salary_formula ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_prorate_salary_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 707 (class 1259 OID 73792)
-- Name: lk_rd_ceiling; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_rd_ceiling (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_rd_ceiling OWNER TO timesadmin;

--
-- TOC entry 706 (class 1259 OID 73791)
-- Name: lk_rd_ceiling_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_rd_ceiling ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_rd_ceiling_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 705 (class 1259 OID 73779)
-- Name: lk_rd_ceiling_method; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_rd_ceiling_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_rd_ceiling_method OWNER TO timesadmin;

--
-- TOC entry 704 (class 1259 OID 73778)
-- Name: lk_rd_ceiling_method_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_rd_ceiling_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_rd_ceiling_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 614 (class 1259 OID 62154)
-- Name: lk_rest_day_rate; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_rest_day_rate (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_rest_day_rate OWNER TO timesadmin;

--
-- TOC entry 613 (class 1259 OID 62153)
-- Name: lk_rest_day_rate_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_rest_day_rate ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_rest_day_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 616 (class 1259 OID 62165)
-- Name: lk_rest_day_status; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_rest_day_status (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_rest_day_status OWNER TO timesadmin;

--
-- TOC entry 615 (class 1259 OID 62164)
-- Name: lk_rest_day_status_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_rest_day_status ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_rest_day_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 618 (class 1259 OID 62176)
-- Name: lk_rounding_method; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_rounding_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_rounding_method OWNER TO timesadmin;

--
-- TOC entry 617 (class 1259 OID 62175)
-- Name: lk_rounding_method_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_rounding_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_rounding_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 891 (class 1259 OID 101376)
-- Name: lk_status; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_status (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    category text NOT NULL,
    name text NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    code character varying(100)
);


ALTER TABLE company.lk_status OWNER TO timesadmin;

--
-- TOC entry 8144 (class 0 OID 0)
-- Dependencies: 891
-- Name: TABLE lk_status; Type: COMMENT; Schema: company; Owner: timesadmin
--

COMMENT ON TABLE company.lk_status IS 'Generic lookup table for status/access values, grouped by category';


--
-- TOC entry 8145 (class 0 OID 0)
-- Dependencies: 891
-- Name: COLUMN lk_status.category; Type: COMMENT; Schema: company; Owner: timesadmin
--

COMMENT ON COLUMN company.lk_status.category IS 'Groups rows by purpose, e.g. QUERY_BUILDER_STATUS, USER_ACCESS_STATUS';


--
-- TOC entry 892 (class 1259 OID 101386)
-- Name: lk_status_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_status ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 757 (class 1259 OID 80486)
-- Name: lk_union_category; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.lk_union_category (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.lk_union_category OWNER TO timesadmin;

--
-- TOC entry 756 (class 1259 OID 80485)
-- Name: lk_union_category_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.lk_union_category ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.lk_union_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 911 (class 1259 OID 105256)
-- Name: module_lock_configuration; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.module_lock_configuration (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    lock_message character varying(200),
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(100),
    updated_on timestamp without time zone,
    updated_by character varying(100)
);


ALTER TABLE company.module_lock_configuration OWNER TO timesadmin;

--
-- TOC entry 910 (class 1259 OID 105255)
-- Name: module_lock_configuration_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.module_lock_configuration ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.module_lock_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 913 (class 1259 OID 105281)
-- Name: module_lock_configuration_module; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.module_lock_configuration_module (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    module_lock_configuration_id bigint NOT NULL,
    module_uid uuid NOT NULL,
    is_locked boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.module_lock_configuration_module OWNER TO timesadmin;

--
-- TOC entry 912 (class 1259 OID 105280)
-- Name: module_lock_configuration_module_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.module_lock_configuration_module ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.module_lock_configuration_module_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 480 (class 1259 OID 36777)
-- Name: my_provident_fund; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.my_provident_fund (
    id bigint NOT NULL,
    company_bank_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    income_tax_number text NOT NULL,
    epf_number text NOT NULL,
    socso_number text NOT NULL,
    asb_number text,
    ptptn_number text,
    tabung_haji_number text,
    zakat_number text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.my_provident_fund OWNER TO timesadmin;

--
-- TOC entry 479 (class 1259 OID 36776)
-- Name: my_provident_fund_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.my_provident_fund ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.my_provident_fund_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 507 (class 1259 OID 38279)
-- Name: my_tax_requirement; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.my_tax_requirement (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    full_name text NOT NULL,
    designation text NOT NULL,
    email text NOT NULL,
    contact_number text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.my_tax_requirement OWNER TO timesadmin;

--
-- TOC entry 506 (class 1259 OID 38278)
-- Name: my_tax_requirement_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.my_tax_requirement ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.my_tax_requirement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 620 (class 1259 OID 62193)
-- Name: npl_configuration; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.npl_configuration (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    daily_rate_formula_id bigint DEFAULT 10 NOT NULL,
    rounding_method_id bigint DEFAULT 2 NOT NULL,
    enable_npl_day boolean DEFAULT true,
    enable_npl_hour boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.npl_configuration OWNER TO timesadmin;

--
-- TOC entry 619 (class 1259 OID 62192)
-- Name: npl_configuration_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.npl_configuration ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.npl_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 622 (class 1259 OID 62221)
-- Name: npl_rate; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.npl_rate (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(255) NOT NULL,
    description character varying(255) NOT NULL,
    cpf bigint NOT NULL,
    is_day boolean DEFAULT false,
    is_hour boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.npl_rate OWNER TO timesadmin;

--
-- TOC entry 621 (class 1259 OID 62220)
-- Name: npl_rate_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.npl_rate ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.npl_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 607 (class 1259 OID 60959)
-- Name: occupation_category; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.occupation_category (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.occupation_category OWNER TO timesadmin;

--
-- TOC entry 606 (class 1259 OID 60958)
-- Name: occupation_category_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.occupation_category ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.occupation_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 482 (class 1259 OID 36798)
-- Name: organization_types; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.organization_types (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    code text
);


ALTER TABLE company.organization_types OWNER TO timesadmin;

--
-- TOC entry 481 (class 1259 OID 36797)
-- Name: organization_types_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.organization_types ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.organization_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 713 (class 1259 OID 73923)
-- Name: ot_capping_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.ot_capping_code (
    id bigint NOT NULL,
    company_ot_capping_id bigint NOT NULL,
    code_id bigint NOT NULL,
    ot_ceiling_method_id bigint DEFAULT 1 NOT NULL,
    ot_ceiling_min numeric,
    ot_ceiling_max numeric,
    fix_rate numeric,
    max_basic_salary numeric,
    is_default boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE company.ot_capping_code OWNER TO timesadmin;

--
-- TOC entry 712 (class 1259 OID 73922)
-- Name: ot_capping_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.ot_capping_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.ot_capping_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 652 (class 1259 OID 63700)
-- Name: ot_rate_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.ot_rate_code (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    ot_rate_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    factor numeric NOT NULL,
    ot_rate_status_id bigint NOT NULL,
    cpf_id bigint NOT NULL,
    tax_id bigint DEFAULT 1 NOT NULL,
    is_grp boolean DEFAULT false NOT NULL,
    is_npl boolean DEFAULT false NOT NULL,
    is_mso boolean DEFAULT true NOT NULL,
    is_ot_cap boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.ot_rate_code OWNER TO timesadmin;

--
-- TOC entry 651 (class 1259 OID 63699)
-- Name: ot_rate_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.ot_rate_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.ot_rate_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 735 (class 1259 OID 77970)
-- Name: pay_group; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.pay_group (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    year text NOT NULL,
    company_id bigint NOT NULL,
    pay_group character varying(255) NOT NULL,
    description character varying(255) NOT NULL,
    weekly_pay_group boolean DEFAULT false NOT NULL,
    start_date date NOT NULL,
    end_date date GENERATED ALWAYS AS ((((start_date + '1 year'::interval) - '1 day'::interval))::date) STORED,
    is_active boolean DEFAULT true NOT NULL,
    day_worked_per_week numeric(18,2) DEFAULT 5.0 NOT NULL,
    hour_worked_per_year numeric(18,2) NOT NULL,
    daily_rate_by bigint NOT NULL,
    working_hours numeric(18,2) DEFAULT 8.0 NOT NULL,
    npl_rate_formula bigint NOT NULL,
    ot_hour_formula bigint NOT NULL,
    is_custom boolean DEFAULT false NOT NULL,
    full_calender jsonb NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT pay_group_day_worked_per_week_check CHECK ((day_worked_per_week > (0)::numeric)),
    CONSTRAINT pay_group_hour_worked_per_year_check CHECK ((hour_worked_per_year > (0)::numeric)),
    CONSTRAINT pay_group_working_hours_check CHECK ((working_hours > (0)::numeric))
);


ALTER TABLE company.pay_group OWNER TO timesadmin;

--
-- TOC entry 739 (class 1259 OID 78044)
-- Name: pay_group_calendar; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.pay_group_calendar (
    id bigint NOT NULL,
    pay_group_id bigint NOT NULL,
    period text NOT NULL,
    start_date date NOT NULL,
    mid_date date NOT NULL,
    end_date date NOT NULL,
    first_half numeric(18,2) DEFAULT 0.00 NOT NULL,
    second_half numeric(18,2) DEFAULT 0.00 NOT NULL,
    ot_start_date date,
    ot_mid_date date,
    ot_end_date date,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT pay_group_calendar_period_check CHECK ((period ~ '^[0-9]{6}$'::text)),
    CONSTRAINT pay_group_calendar_period_check1 CHECK (((("substring"(period, 5, 2))::integer >= 1) AND (("substring"(period, 5, 2))::integer <= 12)))
);


ALTER TABLE company.pay_group_calendar OWNER TO timesadmin;

--
-- TOC entry 738 (class 1259 OID 78043)
-- Name: pay_group_calendar_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.pay_group_calendar ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.pay_group_calendar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 737 (class 1259 OID 78020)
-- Name: pay_group_global_weekly_settings; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.pay_group_global_weekly_settings (
    id bigint NOT NULL,
    pay_group_id bigint NOT NULL,
    week integer DEFAULT 2 NOT NULL,
    day integer DEFAULT 7 NOT NULL,
    working_type company.pay_group_working_type DEFAULT 'Both'::company.pay_group_working_type NOT NULL,
    is_alternate_saturday boolean DEFAULT true NOT NULL,
    public_holiday_off_day boolean DEFAULT false NOT NULL,
    template jsonb NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT pay_group_global_weekly_settings_day_check CHECK (((day > 0) AND (day < 11))),
    CONSTRAINT pay_group_global_weekly_settings_week_check CHECK (((week > 0) AND (week < 11)))
);


ALTER TABLE company.pay_group_global_weekly_settings OWNER TO timesadmin;

--
-- TOC entry 736 (class 1259 OID 78019)
-- Name: pay_group_global_weekly_settings_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.pay_group_global_weekly_settings ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.pay_group_global_weekly_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 734 (class 1259 OID 77969)
-- Name: pay_group_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.pay_group ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.pay_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 741 (class 1259 OID 78066)
-- Name: pay_group_weekly; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.pay_group_weekly (
    id bigint NOT NULL,
    pay_group_id bigint NOT NULL,
    period text NOT NULL,
    week integer NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT pay_group_weekly_period_check CHECK ((period ~ '^[0-9]{6}$'::text)),
    CONSTRAINT pay_group_weekly_period_check1 CHECK (((("substring"(period, 5, 2))::integer >= 1) AND (("substring"(period, 5, 2))::integer <= 12))),
    CONSTRAINT pay_group_weekly_week_check CHECK (((week > 0) AND (week < 7)))
);


ALTER TABLE company.pay_group_weekly OWNER TO timesadmin;

--
-- TOC entry 740 (class 1259 OID 78065)
-- Name: pay_group_weekly_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.pay_group_weekly ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.pay_group_weekly_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 484 (class 1259 OID 36807)
-- Name: payer_types; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.payer_types (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    code text
);


ALTER TABLE company.payer_types OWNER TO timesadmin;

--
-- TOC entry 483 (class 1259 OID 36806)
-- Name: payer_types_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.payer_types ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.payer_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 486 (class 1259 OID 36816)
-- Name: payment_method; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.payment_method (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone,
    created_by text,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.payment_method OWNER TO timesadmin;

--
-- TOC entry 485 (class 1259 OID 36815)
-- Name: payment_method_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.payment_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.payment_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 822 (class 1259 OID 93540)
-- Name: payment_mode; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.payment_mode (
    id smallint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.payment_mode OWNER TO timesadmin;

--
-- TOC entry 454 (class 1259 OID 36437)
-- Name: payment_profile; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.payment_profile (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    profile_name text NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE company.payment_profile OWNER TO timesadmin;

--
-- TOC entry 453 (class 1259 OID 36436)
-- Name: payment_profile_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.payment_profile ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.payment_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 456 (class 1259 OID 36459)
-- Name: payment_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.payment_type (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL
);


ALTER TABLE company.payment_type OWNER TO timesadmin;

--
-- TOC entry 455 (class 1259 OID 36458)
-- Name: payment_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.payment_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.payment_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 723 (class 1259 OID 75573)
-- Name: payroll_financial_period; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.payroll_financial_period (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    year text NOT NULL,
    company_id bigint NOT NULL,
    start_month integer DEFAULT 1 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT payroll_financial_period_start_month_check CHECK (((start_month >= 1) AND (start_month <= 12)))
);


ALTER TABLE company.payroll_financial_period OWNER TO timesadmin;

--
-- TOC entry 722 (class 1259 OID 75572)
-- Name: payroll_financial_period_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.payroll_financial_period ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.payroll_financial_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 565 (class 1259 OID 55859)
-- Name: period_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.period_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'admin'::text NOT NULL
);


ALTER TABLE company.period_type OWNER TO timesadmin;

--
-- TOC entry 564 (class 1259 OID 55858)
-- Name: period_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.period_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.period_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 697 (class 1259 OID 73691)
-- Name: prorate_allowance_configuration; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.prorate_allowance_configuration (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    prorate_payitem_formula_id bigint NOT NULL,
    ot_formula boolean DEFAULT true,
    rd_formula boolean DEFAULT true,
    npl_formula boolean DEFAULT true,
    absent_formula boolean DEFAULT true,
    grp_formula boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.prorate_allowance_configuration OWNER TO timesadmin;

--
-- TOC entry 696 (class 1259 OID 73690)
-- Name: prorate_allowance_configuration_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.prorate_allowance_configuration ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.prorate_allowance_configuration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 699 (class 1259 OID 73718)
-- Name: prorate_allowance_deduction_assignment; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.prorate_allowance_deduction_assignment (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_allowance_deduction_id bigint NOT NULL,
    deduction_code_id bigint NOT NULL,
    prorate_payitem_formula_id bigint NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.prorate_allowance_deduction_assignment OWNER TO timesadmin;

--
-- TOC entry 698 (class 1259 OID 73717)
-- Name: prorate_allowance_deduction_assignment_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.prorate_allowance_deduction_assignment ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.prorate_allowance_deduction_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 703 (class 1259 OID 73759)
-- Name: prorate_allowance_deduction_leave_assignment; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.prorate_allowance_deduction_leave_assignment (
    id bigint NOT NULL,
    company_allowance_deduction_id bigint NOT NULL,
    leave_type bigint NOT NULL,
    sort_order integer,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.prorate_allowance_deduction_leave_assignment OWNER TO timesadmin;

--
-- TOC entry 702 (class 1259 OID 73758)
-- Name: prorate_allowance_deduction_leave_assignment_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.prorate_allowance_deduction_leave_assignment ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.prorate_allowance_deduction_leave_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 689 (class 1259 OID 72377)
-- Name: public_holiday; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.public_holiday (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    public_holiday_type_id bigint NOT NULL,
    name text NOT NULL,
    date date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    company_id integer DEFAULT 1 NOT NULL
);


ALTER TABLE company.public_holiday OWNER TO timesadmin;

--
-- TOC entry 658 (class 1259 OID 64785)
-- Name: public_holiday_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.public_holiday_code (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    public_holiday_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    factor numeric NOT NULL,
    public_holiday_status_id bigint NOT NULL,
    cpf_id bigint NOT NULL,
    is_ot boolean DEFAULT false NOT NULL,
    is_npl boolean DEFAULT false NOT NULL,
    is_mso boolean DEFAULT true NOT NULL,
    public_holiday_rate_id bigint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    tax_id bigint NOT NULL
);


ALTER TABLE company.public_holiday_code OWNER TO timesadmin;

--
-- TOC entry 657 (class 1259 OID 64784)
-- Name: public_holiday_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.public_holiday_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.public_holiday_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 688 (class 1259 OID 72376)
-- Name: public_holiday_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.public_holiday ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.public_holiday_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 687 (class 1259 OID 72364)
-- Name: public_holiday_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.public_holiday_type (
    id bigint NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id integer,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.public_holiday_type OWNER TO timesadmin;

--
-- TOC entry 686 (class 1259 OID 72363)
-- Name: public_holiday_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.public_holiday_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.public_holiday_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 898 (class 1259 OID 101483)
-- Name: query_builder_rule_users; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.query_builder_rule_users (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_on timestamp without time zone,
    rule_id bigint NOT NULL,
    user_id integer NOT NULL,
    status_id bigint NOT NULL,
    created_by integer,
    updated_by integer,
    is_favourite boolean DEFAULT false NOT NULL,
    module_id integer[] DEFAULT '{}'::integer[] NOT NULL,
    favourite_module_id integer[] DEFAULT '{}'::integer[] NOT NULL,
    CONSTRAINT ck_qbru_fav_subset CHECK ((favourite_module_id <@ module_id))
);


ALTER TABLE company.query_builder_rule_users OWNER TO timesadmin;

--
-- TOC entry 8146 (class 0 OID 0)
-- Dependencies: 898
-- Name: COLUMN query_builder_rule_users.is_favourite; Type: COMMENT; Schema: company; Owner: timesadmin
--

COMMENT ON COLUMN company.query_builder_rule_users.is_favourite IS 'Favourite Query star, per user per rule';


--
-- TOC entry 8147 (class 0 OID 0)
-- Dependencies: 898
-- Name: COLUMN query_builder_rule_users.module_id; Type: COMMENT; Schema: company; Owner: timesadmin
--

COMMENT ON COLUMN company.query_builder_rule_users.module_id IS 'This user''s applied products; seeded from query_builder_rules.module_id at grant time, then frozen';


--
-- TOC entry 8148 (class 0 OID 0)
-- Dependencies: 898
-- Name: COLUMN query_builder_rule_users.favourite_module_id; Type: COMMENT; Schema: company; Owner: timesadmin
--

COMMENT ON COLUMN company.query_builder_rule_users.favourite_module_id IS 'Favourite Product tags; always a subset of module_id (ck_qbru_fav_subset)';


--
-- TOC entry 897 (class 1259 OID 101482)
-- Name: query_builder_rule_users_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.query_builder_rule_users ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.query_builder_rule_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 895 (class 1259 OID 101429)
-- Name: query_builder_rules; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.query_builder_rules (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_on timestamp without time zone,
    rules jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    company_id bigint,
    name text NOT NULL,
    description text,
    module_id integer[],
    status_id bigint,
    created_by integer,
    updated_by integer
);


ALTER TABLE company.query_builder_rules OWNER TO timesadmin;

--
-- TOC entry 896 (class 1259 OID 101437)
-- Name: query_builder_rules_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.query_builder_rules ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.query_builder_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 575 (class 1259 OID 56855)
-- Name: relation_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.relation_type (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE company.relation_type OWNER TO timesadmin;

--
-- TOC entry 574 (class 1259 OID 56854)
-- Name: relation_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.relation_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.relation_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 709 (class 1259 OID 73807)
-- Name: rest_day_capping_settings; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.rest_day_capping_settings (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    rd_ceiling_method_id bigint NOT NULL,
    rd_ceiling_min numeric(18,2) DEFAULT 0.00 NOT NULL,
    rd_ceiling_max numeric(18,2) DEFAULT 0.00 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.rest_day_capping_settings OWNER TO timesadmin;

--
-- TOC entry 708 (class 1259 OID 73806)
-- Name: rest_day_capping_settings_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.rest_day_capping_settings ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.rest_day_capping_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 640 (class 1259 OID 62917)
-- Name: rest_day_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.rest_day_code (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    rest_day_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    factor numeric NOT NULL,
    rest_day_status_id bigint NOT NULL,
    cpf_id bigint NOT NULL,
    tax_id bigint NOT NULL,
    rest_day_rate_id bigint NOT NULL,
    is_npl boolean DEFAULT false NOT NULL,
    is_mso boolean DEFAULT true NOT NULL,
    is_ot boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    is_default boolean DEFAULT true NOT NULL
);


ALTER TABLE company.rest_day_code OWNER TO timesadmin;

--
-- TOC entry 639 (class 1259 OID 62916)
-- Name: rest_day_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.rest_day_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.rest_day_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 880 (class 1259 OID 100431)
-- Name: salary_scale_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.salary_scale_setup (
    salary_scale_id bigint NOT NULL,
    salary_scale_type_id integer GENERATED ALWAYS AS (73) STORED NOT NULL,
    minimum numeric NOT NULL,
    maximum numeric NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.salary_scale_setup OWNER TO timesadmin;

--
-- TOC entry 882 (class 1259 OID 100447)
-- Name: salary_scale_step; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.salary_scale_step (
    id bigint NOT NULL,
    salary_scale_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    step numeric NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.salary_scale_step OWNER TO timesadmin;

--
-- TOC entry 881 (class 1259 OID 100446)
-- Name: salary_scale_step_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.salary_scale_step ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.salary_scale_step_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 747 (class 1259 OID 78115)
-- Name: sg_community_fund_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_community_fund_setup (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id bigint NOT NULL,
    tax_id bigint NOT NULL,
    cpf_id bigint NOT NULL,
    benefit_in_kind_id bigint,
    unit_id bigint,
    grp_formula_id bigint,
    gross_wage_id bigint,
    backpay_allowance_id bigint,
    type_id bigint NOT NULL,
    bonus_type_id bigint,
    alert_deduction_resigned_employee boolean DEFAULT true NOT NULL,
    custom_report_group_code text,
    payslip_group_code text,
    sdf boolean DEFAULT false,
    nsp boolean DEFAULT false,
    community_funds boolean DEFAULT false,
    ot boolean DEFAULT false,
    npl boolean DEFAULT false,
    grp boolean DEFAULT false,
    rd boolean DEFAULT false,
    non_payroll_item boolean DEFAULT false,
    oed_gross_wage boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    year integer DEFAULT EXTRACT(year FROM CURRENT_DATE) NOT NULL
);


ALTER TABLE company.sg_community_fund_setup OWNER TO timesadmin;

--
-- TOC entry 746 (class 1259 OID 78114)
-- Name: sg_community_fund_setup_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_community_fund_setup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_community_fund_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 813 (class 1259 OID 92045)
-- Name: sg_cpf_profile; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_cpf_profile (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    description text NOT NULL,
    company_id bigint NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.sg_cpf_profile OWNER TO timesadmin;

--
-- TOC entry 812 (class 1259 OID 92044)
-- Name: sg_cpf_profile_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_cpf_profile ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_cpf_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 753 (class 1259 OID 78299)
-- Name: sg_cpf_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_cpf_setup (
    id bigint NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    age_group_id bigint DEFAULT 1 NOT NULL,
    contribution_type_id bigint DEFAULT 1 NOT NULL,
    cpf_profile_id bigint NOT NULL,
    effective_date date DEFAULT now() NOT NULL,
    employee_formula text,
    employee_rate numeric,
    employer_rate numeric,
    ow_ceiling numeric NOT NULL,
    total_formula text,
    total_rate numeric,
    tw_group_id bigint NOT NULL
);


ALTER TABLE company.sg_cpf_setup OWNER TO timesadmin;

--
-- TOC entry 752 (class 1259 OID 78298)
-- Name: sg_cpf_setup_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_cpf_setup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_cpf_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 749 (class 1259 OID 78193)
-- Name: sg_donation_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_donation_setup (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id bigint NOT NULL,
    tax_id bigint NOT NULL,
    cpf_id bigint NOT NULL,
    benefit_in_kind_id bigint,
    unit_id bigint,
    grp_formula_id bigint,
    gross_wage_id bigint,
    backpay_allowance_id bigint,
    type_id bigint NOT NULL,
    bonus_type_id bigint,
    alert_deduction_resigned_employee boolean DEFAULT true NOT NULL,
    custom_report_group_code text,
    payslip_group_code text,
    sdf boolean DEFAULT false,
    nsp boolean DEFAULT false,
    community_funds boolean DEFAULT false,
    ot boolean DEFAULT false,
    npl boolean DEFAULT false,
    grp boolean DEFAULT false,
    rd boolean DEFAULT false,
    non_payroll_item boolean DEFAULT false,
    oed_gross_wage boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    year integer DEFAULT EXTRACT(year FROM CURRENT_DATE) NOT NULL
);


ALTER TABLE company.sg_donation_setup OWNER TO timesadmin;

--
-- TOC entry 748 (class 1259 OID 78192)
-- Name: sg_donation_setup_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_donation_setup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_donation_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 807 (class 1259 OID 91962)
-- Name: sg_donation_setup_link; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_donation_setup_link (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_active boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    inactive_code_ids integer[],
    src_company_id bigint NOT NULL
);


ALTER TABLE company.sg_donation_setup_link OWNER TO timesadmin;

--
-- TOC entry 806 (class 1259 OID 91961)
-- Name: sg_donation_setup_link_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_donation_setup_link ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_donation_setup_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 609 (class 1259 OID 60970)
-- Name: sg_highest_education_attained; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_highest_education_attained (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.sg_highest_education_attained OWNER TO timesadmin;

--
-- TOC entry 608 (class 1259 OID 60969)
-- Name: sg_highest_education_attained_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_highest_education_attained ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_highest_education_attained_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 611 (class 1259 OID 60981)
-- Name: sg_occupation_group; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_occupation_group (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.sg_occupation_group OWNER TO timesadmin;

--
-- TOC entry 610 (class 1259 OID 60980)
-- Name: sg_occupation_group_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_occupation_group ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_occupation_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 642 (class 1259 OID 63583)
-- Name: sg_oed_map_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_oed_map_code (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    code_setup_type_id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE company.sg_oed_map_code OWNER TO timesadmin;

--
-- TOC entry 641 (class 1259 OID 63582)
-- Name: sg_oed_map_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_oed_map_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_oed_map_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 488 (class 1259 OID 36824)
-- Name: sg_provident_fund; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_provident_fund (
    id integer NOT NULL,
    company_bank_id bigint NOT NULL,
    voluntary_suffix character varying(5) NOT NULL,
    voluntary_account_number character varying(20) NOT NULL,
    income_tax_number character varying(10) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    cpf_number bytea NOT NULL
);


ALTER TABLE company.sg_provident_fund OWNER TO timesadmin;

--
-- TOC entry 487 (class 1259 OID 36823)
-- Name: sg_provident_fund_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_provident_fund ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.sg_provident_fund_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 490 (class 1259 OID 36842)
-- Name: sg_tax_requirement; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_tax_requirement (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    full_name text NOT NULL,
    designation text NOT NULL,
    email text NOT NULL,
    contact_number text NOT NULL,
    organization_types_id bigint NOT NULL,
    payer_types_id bigint NOT NULL,
    ir21_full_name text NOT NULL,
    ir21_contact_person_full_name text NOT NULL,
    ir21_designation text NOT NULL,
    ir21_email text NOT NULL,
    ir21_contact_number text NOT NULL,
    ir21_eris_start_date date,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50) DEFAULT 'Admin'::character varying NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE company.sg_tax_requirement OWNER TO timesadmin;

--
-- TOC entry 489 (class 1259 OID 36841)
-- Name: sg_tax_requirement_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_tax_requirement ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME company.sg_tax_requirement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 759 (class 1259 OID 80497)
-- Name: sg_union_setup; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_union_setup (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id bigint NOT NULL,
    tax_id bigint NOT NULL,
    cpf_id bigint NOT NULL,
    benefit_in_kind_id bigint,
    unit_id bigint,
    grp_formula_id bigint,
    gross_wage_id bigint,
    backpay_allowance_id bigint,
    type_id bigint NOT NULL,
    bonus_type_id bigint,
    alert_deduction_resigned_employee boolean DEFAULT true NOT NULL,
    custom_report_group_code text,
    payslip_group_code text,
    sdf boolean DEFAULT false,
    nsp boolean DEFAULT false,
    community_funds boolean DEFAULT false,
    ot boolean DEFAULT false,
    npl boolean DEFAULT false,
    grp boolean DEFAULT false,
    rd boolean DEFAULT false,
    non_payroll_item boolean DEFAULT false,
    oed_gross_wage boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    year integer DEFAULT EXTRACT(year FROM CURRENT_DATE) NOT NULL
);


ALTER TABLE company.sg_union_setup OWNER TO timesadmin;

--
-- TOC entry 758 (class 1259 OID 80496)
-- Name: sg_union_setup_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_union_setup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_union_setup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 815 (class 1259 OID 92099)
-- Name: sg_union_setup_link; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.sg_union_setup_link (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_active boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    inactive_code_ids integer[],
    src_company_id bigint NOT NULL
);


ALTER TABLE company.sg_union_setup_link OWNER TO timesadmin;

--
-- TOC entry 814 (class 1259 OID 92098)
-- Name: sg_union_setup_link_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.sg_union_setup_link ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.sg_union_setup_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 670 (class 1259 OID 65037)
-- Name: shift_setup_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.shift_setup_code (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    shift_setup_id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    unit_id bigint DEFAULT 1 NOT NULL,
    rate numeric DEFAULT 1 NOT NULL,
    cpf_id bigint DEFAULT 1 NOT NULL,
    tax_id bigint DEFAULT 1 NOT NULL,
    is_grp boolean DEFAULT false NOT NULL,
    is_npl boolean DEFAULT false NOT NULL,
    is_mso boolean DEFAULT true NOT NULL,
    is_ot boolean DEFAULT false NOT NULL,
    is_rd boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.shift_setup_code OWNER TO timesadmin;

--
-- TOC entry 669 (class 1259 OID 65036)
-- Name: shift_setup_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.shift_setup_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.shift_setup_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 719 (class 1259 OID 75531)
-- Name: union; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company."union" (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    union_type_id bigint NOT NULL,
    "from" numeric(18,2) NOT NULL,
    "to" numeric(18,2) NOT NULL,
    rate numeric(18,2) NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company."union" OWNER TO timesadmin;

--
-- TOC entry 721 (class 1259 OID 75552)
-- Name: union_bonus; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.union_bonus (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    union_type_id bigint NOT NULL,
    "from" numeric(18,2) NOT NULL,
    "to" numeric(18,2) NOT NULL,
    rate numeric(18,2) NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE company.union_bonus OWNER TO timesadmin;

--
-- TOC entry 720 (class 1259 OID 75551)
-- Name: union_bonus_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.union_bonus ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.union_bonus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 717 (class 1259 OID 75513)
-- Name: union_bonus_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.union_bonus_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    year text NOT NULL,
    company_id bigint,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE company.union_bonus_type OWNER TO timesadmin;

--
-- TOC entry 716 (class 1259 OID 75512)
-- Name: union_bonus_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.union_bonus_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.union_bonus_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 718 (class 1259 OID 75530)
-- Name: union_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company."union" ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.union_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 715 (class 1259 OID 75495)
-- Name: union_type; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.union_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    year text NOT NULL,
    company_id bigint,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE company.union_type OWNER TO timesadmin;

--
-- TOC entry 714 (class 1259 OID 75494)
-- Name: union_type_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.union_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.union_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 685 (class 1259 OID 70261)
-- Name: work_code; Type: TABLE; Schema: company; Owner: timesadmin
--

CREATE TABLE company.work_code (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint NOT NULL,
    year integer DEFAULT EXTRACT(year FROM CURRENT_DATE) NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    days integer NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE company.work_code OWNER TO timesadmin;

--
-- TOC entry 684 (class 1259 OID 70260)
-- Name: work_code_id_seq; Type: SEQUENCE; Schema: company; Owner: timesadmin
--

ALTER TABLE company.work_code ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.work_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 799 (class 1259 OID 89749)
-- Name: address_usage_type; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.address_usage_type (
    address_id bigint NOT NULL,
    usage_tag_id bigint NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.address_usage_type OWNER TO timesadmin;

--
-- TOC entry 877 (class 1259 OID 98094)
-- Name: career_progression; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.career_progression (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    career_progression_code_id bigint NOT NULL,
    career_progression_code_type_id bigint GENERATED ALWAYS AS (17) STORED,
    appraisal_grade_id bigint,
    appraisal_grade_type_id bigint GENERATED ALWAYS AS (72) STORED,
    salary_scale_id bigint,
    salary_scale_type_id bigint GENERATED ALWAYS AS (73) STORED,
    occupation_id bigint NOT NULL,
    occupation_type_id bigint GENERATED ALWAYS AS (25) STORED,
    job_level_id bigint NOT NULL,
    job_level_type_id bigint GENERATED ALWAYS AS (74) STORED,
    job_grade_id bigint NOT NULL,
    job_grade_type_id bigint GENERATED ALWAYS AS (75) STORED,
    cost_centre_id bigint NOT NULL,
    cost_centre_type_id bigint GENERATED ALWAYS AS (76) STORED,
    branch_id bigint,
    branch_type_id bigint GENERATED ALWAYS AS (77) STORED,
    location_id bigint,
    location_type_id bigint GENERATED ALWAYS AS (78) STORED,
    employment_classification_id bigint,
    employment_classification_type_id bigint GENERATED ALWAYS AS (65) STORED,
    classification_id bigint,
    classification_type_id bigint GENERATED ALWAYS AS (79) STORED,
    category_id bigint,
    category_type_id bigint GENERATED ALWAYS AS (80) STORED,
    department_id bigint,
    department_type_id bigint GENERATED ALWAYS AS (66) STORED,
    division_id bigint,
    division_type_id bigint GENERATED ALWAYS AS (69) STORED,
    section_id bigint,
    section_type_id bigint GENERATED ALWAYS AS (70) STORED,
    unit_id bigint,
    unit_type_id bigint GENERATED ALWAYS AS (67) STORED,
    team_id bigint,
    team_type_id bigint GENERATED ALWAYS AS (68) STORED,
    old_salary numeric(18,2),
    adjusted_amount numeric(18,2),
    new_salary numeric(18,2),
    adjustment_percent numeric(18,2),
    effective_date date NOT NULL,
    pay_effective_date date NOT NULL,
    next_review_date date,
    is_mvc boolean DEFAULT false NOT NULL,
    reason text,
    remark text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.career_progression OWNER TO timesadmin;

--
-- TOC entry 876 (class 1259 OID 98093)
-- Name: career_progression_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.career_progression ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.career_progression_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 846 (class 1259 OID 93852)
-- Name: contract_allowance_deduction; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_allowance_deduction (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    pay_code_id bigint NOT NULL,
    amount_type_id bigint NOT NULL,
    currency_code_id bigint NOT NULL,
    currency_code_type_id integer GENERATED ALWAYS AS (9) STORED NOT NULL,
    effective_date date NOT NULL,
    payment_date date NOT NULL,
    recurring_method_id bigint NOT NULL,
    end_date date,
    amount numeric NOT NULL,
    is_affected_last_payment_date boolean DEFAULT false,
    is_week_1 boolean DEFAULT false,
    is_week_2 boolean DEFAULT false,
    is_week_3 boolean DEFAULT false,
    is_week_4 boolean DEFAULT false,
    is_week_5 boolean DEFAULT false,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    payroll_cycle_id bigint NOT NULL
);


ALTER TABLE employee.contract_allowance_deduction OWNER TO timesadmin;

--
-- TOC entry 845 (class 1259 OID 93851)
-- Name: contract_allowance_deduction_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_allowance_deduction ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_allowance_deduction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 811 (class 1259 OID 92006)
-- Name: contract_donations; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_donations (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    donation_type_id bigint NOT NULL,
    period_id bigint NOT NULL,
    amount numeric NOT NULL,
    effective_date timestamp without time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.contract_donations OWNER TO timesadmin;

--
-- TOC entry 810 (class 1259 OID 92005)
-- Name: contract_donations_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_donations ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_donations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 798 (class 1259 OID 89732)
-- Name: contract_hr_note; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_hr_note (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    note text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.contract_hr_note OWNER TO timesadmin;

--
-- TOC entry 797 (class 1259 OID 89731)
-- Name: contract_hr_note_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_hr_note ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_hr_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 840 (class 1259 OID 93771)
-- Name: contract_pay_setting; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_pay_setting (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    pay_group_id bigint NOT NULL,
    pay_type_id bigint,
    pay_type_code_id integer GENERATED ALWAYS AS (12) STORED NOT NULL,
    is_mid_month_pay_percentage boolean,
    mid_month_pay numeric,
    is_semi_month boolean,
    bonus_factor numeric,
    daily_rate_formula_id bigint NOT NULL,
    hourly_rate_formula_id bigint NOT NULL,
    working_code_id bigint,
    work_code_salary_month integer,
    festival_advance_id bigint,
    hour_worked_per_year numeric NOT NULL,
    day_worked_per_week numeric NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.contract_pay_setting OWNER TO timesadmin;

--
-- TOC entry 839 (class 1259 OID 93770)
-- Name: contract_pay_setting_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_pay_setting ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_pay_setting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 796 (class 1259 OID 89702)
-- Name: contract_resignation; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_resignation (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    reason_id bigint NOT NULL,
    reason_type_id integer GENERATED ALWAYS AS (24) STORED NOT NULL,
    notice_period integer NOT NULL,
    notice_period_type_id bigint NOT NULL,
    tender_date timestamp without time zone DEFAULT now() NOT NULL,
    resignation_date timestamp without time zone NOT NULL,
    last_payment_date timestamp without time zone NOT NULL,
    last_day_of_work timestamp without time zone NOT NULL,
    is_reemployment boolean DEFAULT false NOT NULL,
    is_leave_review boolean DEFAULT false NOT NULL,
    additional_note text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.contract_resignation OWNER TO timesadmin;

--
-- TOC entry 795 (class 1259 OID 89701)
-- Name: contract_resignation_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_resignation ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_resignation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 848 (class 1259 OID 93900)
-- Name: contract_scheme; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_scheme (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    scheme_code_id bigint NOT NULL,
    public_holiday_type_id bigint,
    scheme_type text DEFAULT 'leave'::text NOT NULL,
    effective_date date NOT NULL,
    is_shift_worker boolean,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.contract_scheme OWNER TO timesadmin;

--
-- TOC entry 847 (class 1259 OID 93899)
-- Name: contract_scheme_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_scheme ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_scheme_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 836 (class 1259 OID 93692)
-- Name: contract_service_point; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_service_point (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    period_id bigint NOT NULL,
    allowance_deduction_id bigint NOT NULL,
    service_point numeric NOT NULL,
    amount_point numeric NOT NULL,
    total numeric NOT NULL,
    first_half_percent numeric,
    is_cvp_scheme boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.contract_service_point OWNER TO timesadmin;

--
-- TOC entry 835 (class 1259 OID 93691)
-- Name: contract_service_point_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_service_point ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_service_point_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 852 (class 1259 OID 93940)
-- Name: contract_stop_payment; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.contract_stop_payment (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    stop_payment_indicator_id integer NOT NULL,
    effective_date date NOT NULL,
    end_date date NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.contract_stop_payment OWNER TO timesadmin;

--
-- TOC entry 851 (class 1259 OID 93939)
-- Name: contract_stop_payment_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.contract_stop_payment ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.contract_stop_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 778 (class 1259 OID 89248)
-- Name: epm_ns_record; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.epm_ns_record (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    regulatory_id integer NOT NULL,
    ns_status_id integer NOT NULL,
    ns_status_type_id integer DEFAULT 46 NOT NULL,
    nature_of_service_id integer NOT NULL,
    nature_of_service_type_id integer DEFAULT 71 NOT NULL,
    vocation_id integer NOT NULL,
    vocation_type_id integer DEFAULT 47 NOT NULL,
    rank_id integer NOT NULL,
    rank_type_id integer DEFAULT 49 NOT NULL,
    rating_id integer NOT NULL,
    rating_type_id integer DEFAULT 50 NOT NULL,
    duration_of_service character varying(255) NOT NULL,
    disruption_date_from date,
    disruption_date_to date,
    ns_enlistment_date date,
    ns_psa_service_indicator boolean,
    ns_ord_date date,
    ns_deferred_til_date date,
    csp_enlistment_date date,
    csp_ord_date date,
    csp_ns_increment_granted boolean DEFAULT false NOT NULL,
    csp_service_length character varying(255),
    res_status_id integer,
    res_status_type_id integer DEFAULT 51,
    res_vocation_id integer,
    res_vocation_type_id integer DEFAULT 52,
    res_type_id integer,
    res_type_type_id integer DEFAULT 53,
    res_rank_id integer,
    res_rank_type_id integer DEFAULT 54,
    res_unit_id integer,
    res_unit_type_id integer DEFAULT 55,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(255) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(255)
);


ALTER TABLE employee.epm_ns_record OWNER TO timesadmin;

--
-- TOC entry 777 (class 1259 OID 89247)
-- Name: epm_ns_record_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

CREATE SEQUENCE employee.epm_ns_record_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE employee.epm_ns_record_id_seq OWNER TO timesadmin;

--
-- TOC entry 8149 (class 0 OID 0)
-- Dependencies: 777
-- Name: epm_ns_record_id_seq; Type: SEQUENCE OWNED BY; Schema: employee; Owner: timesadmin
--

ALTER SEQUENCE employee.epm_ns_record_id_seq OWNED BY employee.epm_ns_record.id;


--
-- TOC entry 817 (class 1259 OID 92188)
-- Name: epm_union_info; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.epm_union_info (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    regulatory_id integer NOT NULL,
    union_worker_id integer,
    union_type_id integer,
    union_bonus_id integer,
    join_date date,
    leave_date date,
    created_by character varying(100),
    created_on timestamp with time zone DEFAULT now() NOT NULL,
    updated_by character varying(100),
    updated_on timestamp with time zone
);


ALTER TABLE employee.epm_union_info OWNER TO timesadmin;

--
-- TOC entry 818 (class 1259 OID 92209)
-- Name: epm_union_info_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

CREATE SEQUENCE employee.epm_union_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER SEQUENCE employee.epm_union_info_id_seq OWNER TO timesadmin;

--
-- TOC entry 8150 (class 0 OID 0)
-- Dependencies: 818
-- Name: epm_union_info_id_seq; Type: SEQUENCE OWNED BY; Schema: employee; Owner: timesadmin
--

ALTER SEQUENCE employee.epm_union_info_id_seq OWNED BY employee.epm_union_info.id;


--
-- TOC entry 820 (class 1259 OID 93449)
-- Name: epm_union_info_id_seq1; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.epm_union_info ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.epm_union_info_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 776 (class 1259 OID 89220)
-- Name: epm_work_pass_records; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.epm_work_pass_records (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    regulatory_id integer NOT NULL,
    fin character varying(20) NOT NULL,
    work_pass_type_id integer DEFAULT 59,
    pass_status_id integer NOT NULL,
    application_date date NOT NULL,
    pass_issue_date date NOT NULL,
    pass_expiry_date date NOT NULL,
    mom_letter_no character varying(100),
    medical_insurance_policy_no character varying(100),
    cancellation_date date,
    created_on timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying(255) NOT NULL,
    updated_on timestamp with time zone,
    updated_by character varying(255),
    levy_management_id bigint,
    work_pass_id bigint
);


ALTER TABLE employee.epm_work_pass_records OWNER TO timesadmin;

--
-- TOC entry 775 (class 1259 OID 89219)
-- Name: epm_work_pass_records_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

CREATE SEQUENCE employee.epm_work_pass_records_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE employee.epm_work_pass_records_id_seq OWNER TO timesadmin;

--
-- TOC entry 8151 (class 0 OID 0)
-- Dependencies: 775
-- Name: epm_work_pass_records_id_seq; Type: SEQUENCE OWNED BY; Schema: employee; Owner: timesadmin
--

ALTER SEQUENCE employee.epm_work_pass_records_id_seq OWNED BY employee.epm_work_pass_records.id;


--
-- TOC entry 858 (class 1259 OID 95453)
-- Name: family_info; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.family_info (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id integer NOT NULL,
    full_name character varying(225) NOT NULL,
    relationship_id bigint NOT NULL,
    date_of_birth date NOT NULL,
    gender public.gender_type NOT NULL,
    nationality_id bigint NOT NULL,
    marital_status_id bigint,
    marriage_date date,
    is_adopted_child boolean DEFAULT false NOT NULL,
    extend_paternity_expiry date,
    childcare_effective_date date,
    phone_number character varying(20) NOT NULL,
    email_address character varying(225),
    address character varying(225),
    occupation character varying(225),
    benefit_flag_ids integer[] DEFAULT ARRAY[]::integer[] NOT NULL,
    dependent_status_id bigint NOT NULL,
    special_needs character varying(225),
    remarks character varying(225),
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    identification_number bytea NOT NULL,
    adopted_date date
);


ALTER TABLE employee.family_info OWNER TO timesadmin;

--
-- TOC entry 857 (class 1259 OID 95452)
-- Name: family_info_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.family_info ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.family_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 786 (class 1259 OID 89517)
-- Name: lk_address_type; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_address_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_address_type OWNER TO timesadmin;

--
-- TOC entry 785 (class 1259 OID 89516)
-- Name: lk_address_type_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_address_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_address_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 832 (class 1259 OID 93670)
-- Name: lk_amount_type; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_amount_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_amount_type OWNER TO timesadmin;

--
-- TOC entry 831 (class 1259 OID 93669)
-- Name: lk_amount_type_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_amount_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_amount_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 856 (class 1259 OID 95440)
-- Name: lk_dependent_status; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_dependent_status (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_dependent_status OWNER TO timesadmin;

--
-- TOC entry 855 (class 1259 OID 95439)
-- Name: lk_dependent_status_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_dependent_status ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_dependent_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 809 (class 1259 OID 91995)
-- Name: lk_donation_period; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_donation_period (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_donation_period OWNER TO timesadmin;

--
-- TOC entry 808 (class 1259 OID 91994)
-- Name: lk_donation_period_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_donation_period ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_donation_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 854 (class 1259 OID 95427)
-- Name: lk_family_benefit_flag; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_family_benefit_flag (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_family_benefit_flag OWNER TO timesadmin;

--
-- TOC entry 853 (class 1259 OID 95426)
-- Name: lk_family_benefit_flag_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_family_benefit_flag ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_family_benefit_flag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 834 (class 1259 OID 93681)
-- Name: lk_festival_advance; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_festival_advance (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_festival_advance OWNER TO timesadmin;

--
-- TOC entry 833 (class 1259 OID 93680)
-- Name: lk_festival_advance_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_festival_advance ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_festival_advance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 873 (class 1259 OID 97777)
-- Name: lk_fund_topup_type; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_fund_topup_type (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_fund_topup_type OWNER TO timesadmin;

--
-- TOC entry 872 (class 1259 OID 97776)
-- Name: lk_fund_topup_type_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_fund_topup_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_fund_topup_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 770 (class 1259 OID 89163)
-- Name: lk_pass_status; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_pass_status (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    is_cancellation_date_required boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE employee.lk_pass_status OWNER TO timesadmin;

--
-- TOC entry 769 (class 1259 OID 89162)
-- Name: lk_pass_status_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

CREATE SEQUENCE employee.lk_pass_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE employee.lk_pass_status_id_seq OWNER TO timesadmin;

--
-- TOC entry 8152 (class 0 OID 0)
-- Dependencies: 769
-- Name: lk_pass_status_id_seq; Type: SEQUENCE OWNED BY; Schema: employee; Owner: timesadmin
--

ALTER SEQUENCE employee.lk_pass_status_id_seq OWNED BY employee.lk_pass_status.id;


--
-- TOC entry 828 (class 1259 OID 93648)
-- Name: lk_recurring_method; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_recurring_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_recurring_method OWNER TO timesadmin;

--
-- TOC entry 827 (class 1259 OID 93647)
-- Name: lk_recurring_method_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_recurring_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_recurring_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 790 (class 1259 OID 89539)
-- Name: lk_service_grade; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_service_grade (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_service_grade OWNER TO timesadmin;

--
-- TOC entry 789 (class 1259 OID 89538)
-- Name: lk_service_grade_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_service_grade ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_service_grade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 830 (class 1259 OID 93659)
-- Name: lk_service_point_period; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_service_point_period (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_service_point_period OWNER TO timesadmin;

--
-- TOC entry 829 (class 1259 OID 93658)
-- Name: lk_service_point_period_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_service_point_period ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_service_point_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 850 (class 1259 OID 93928)
-- Name: lk_stop_payment_indicator; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_stop_payment_indicator (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    has_end_date boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.lk_stop_payment_indicator OWNER TO timesadmin;

--
-- TOC entry 849 (class 1259 OID 93927)
-- Name: lk_stop_payment_indicator_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_stop_payment_indicator ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_stop_payment_indicator_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 816 (class 1259 OID 92178)
-- Name: lk_union_worker; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_union_worker (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE employee.lk_union_worker OWNER TO timesadmin;

--
-- TOC entry 819 (class 1259 OID 92765)
-- Name: lk_union_worker_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

CREATE SEQUENCE employee.lk_union_worker_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER SEQUENCE employee.lk_union_worker_id_seq OWNER TO timesadmin;

--
-- TOC entry 8153 (class 0 OID 0)
-- Dependencies: 819
-- Name: lk_union_worker_id_seq; Type: SEQUENCE OWNED BY; Schema: employee; Owner: timesadmin
--

ALTER SEQUENCE employee.lk_union_worker_id_seq OWNED BY employee.lk_union_worker.id;


--
-- TOC entry 788 (class 1259 OID 89528)
-- Name: lk_usage_tag; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.lk_usage_tag (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text
);


ALTER TABLE employee.lk_usage_tag OWNER TO timesadmin;

--
-- TOC entry 787 (class 1259 OID 89527)
-- Name: lk_usage_tag_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.lk_usage_tag ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.lk_usage_tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 842 (class 1259 OID 93820)
-- Name: pay_setting_work_calendar; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.pay_setting_work_calendar (
    id bigint NOT NULL,
    pay_setting_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    weekly_setting jsonb NOT NULL,
    yearly_calendar_setting jsonb NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    global_setting_week integer DEFAULT 2 NOT NULL,
    global_setting_day integer DEFAULT 7 NOT NULL,
    global_setting_public_holiday_off_day boolean DEFAULT false NOT NULL
);


ALTER TABLE employee.pay_setting_work_calendar OWNER TO timesadmin;

--
-- TOC entry 841 (class 1259 OID 93819)
-- Name: pay_setting_work_calendar_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.pay_setting_work_calendar ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.pay_setting_work_calendar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 824 (class 1259 OID 93550)
-- Name: payment_profile; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.payment_profile (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    contract_id bigint NOT NULL,
    profile_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    effective_date date NOT NULL,
    bank_type_id smallint NOT NULL,
    is_preferred boolean DEFAULT false NOT NULL,
    overflow_payment_mode_id smallint,
    overflow_bank_id integer,
    overflow_branch_id bigint,
    overflow_reference text,
    remarks text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    overflow_account_number bytea,
    company_id bigint NOT NULL,
    CONSTRAINT chk_overflow_consistency CHECK ((((overflow_payment_mode_id IS NULL) AND (overflow_bank_id IS NULL) AND (overflow_branch_id IS NULL) AND (overflow_account_number IS NULL) AND (overflow_reference IS NULL)) OR ((overflow_payment_mode_id = 1) AND (overflow_bank_id IS NOT NULL) AND (overflow_branch_id IS NOT NULL) AND (overflow_account_number IS NOT NULL)) OR ((overflow_payment_mode_id = ANY (ARRAY[2, 3])) AND (overflow_bank_id IS NULL) AND (overflow_branch_id IS NULL) AND (overflow_account_number IS NULL))))
);


ALTER TABLE employee.payment_profile OWNER TO timesadmin;

--
-- TOC entry 823 (class 1259 OID 93549)
-- Name: payment_profile_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.payment_profile ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.payment_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 826 (class 1259 OID 93597)
-- Name: payment_split; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.payment_split (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    payment_profile_id bigint NOT NULL,
    sort smallint NOT NULL,
    payment_mode_id smallint NOT NULL,
    bank_id integer,
    bank_branch_id bigint,
    is_percentage boolean NOT NULL,
    percentage numeric(5,2),
    amount numeric(18,2),
    reference text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    account_number bytea,
    CONSTRAINT chk_split_bank_fields CHECK ((((payment_mode_id = 1) AND (bank_id IS NOT NULL) AND (bank_branch_id IS NOT NULL) AND (account_number IS NOT NULL)) OR ((payment_mode_id = ANY (ARRAY[2, 3])) AND (bank_id IS NULL) AND (bank_branch_id IS NULL) AND (account_number IS NULL)))),
    CONSTRAINT chk_split_value CHECK (((is_percentage AND (percentage IS NOT NULL) AND (percentage > (0)::numeric) AND (percentage <= (100)::numeric) AND (amount IS NULL)) OR ((NOT is_percentage) AND (percentage IS NULL) AND ((amount IS NULL) OR (amount > (0)::numeric)))))
);


ALTER TABLE employee.payment_split OWNER TO timesadmin;

--
-- TOC entry 825 (class 1259 OID 93596)
-- Name: payment_split_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.payment_split ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.payment_split_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 838 (class 1259 OID 93721)
-- Name: service_point_payslip_message; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.service_point_payslip_message (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    service_point_id bigint NOT NULL,
    message text NOT NULL,
    remark text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.service_point_payslip_message OWNER TO timesadmin;

--
-- TOC entry 837 (class 1259 OID 93720)
-- Name: service_point_payslip_message_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.service_point_payslip_message ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.service_point_payslip_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 794 (class 1259 OID 89665)
-- Name: user_company_address; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_company_address (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    address_type_id bigint NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    effective_start_date timestamp without time zone DEFAULT now() NOT NULL,
    effective_end_date timestamp without time zone,
    is_active boolean DEFAULT true NOT NULL,
    is_sg boolean DEFAULT true NOT NULL,
    postal_code text,
    block_number text,
    street_name text,
    building_name text,
    unit_number text,
    address_line_1 text,
    address_line_2 text,
    city text,
    state text,
    contact_info text,
    additional_note text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    country_id bigint,
    user_id bigint NOT NULL,
    country_type_id integer GENERATED ALWAYS AS (56) STORED
);


ALTER TABLE employee.user_company_address OWNER TO timesadmin;

--
-- TOC entry 793 (class 1259 OID 89664)
-- Name: user_company_address_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_company_address ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_company_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 868 (class 1259 OID 95711)
-- Name: user_company_asset; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_company_asset (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    company_id bigint NOT NULL,
    asset_id bigint NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    assigned_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE employee.user_company_asset OWNER TO timesadmin;

--
-- TOC entry 867 (class 1259 OID 95710)
-- Name: user_company_asset_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_company_asset ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_company_asset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 792 (class 1259 OID 89566)
-- Name: user_company_contract; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_company_contract (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    company_id bigint NOT NULL,
    contract_id text NOT NULL,
    contract_type_id bigint NOT NULL,
    contract_start_date timestamp without time zone DEFAULT now() NOT NULL,
    contract_end_date timestamp without time zone,
    is_active boolean DEFAULT true NOT NULL,
    effective_service_date timestamp without time zone DEFAULT now() NOT NULL,
    is_exclude_payroll boolean DEFAULT false NOT NULL,
    employee_no text,
    staff_card_no text,
    office_phone_no text,
    phone_ext integer,
    service_grade_id bigint,
    probation_period integer,
    probation_period_type_id bigint,
    confirmation_date timestamp without time zone,
    confirmation_on timestamp without time zone,
    retired_age integer,
    currency_code_id bigint NOT NULL,
    payment_profile_id bigint NOT NULL,
    sg_provident_fund_id bigint,
    my_provident_fund_id bigint,
    id_provident_fund_id bigint,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    contract_type_code_id integer GENERATED ALWAYS AS (16) STORED NOT NULL,
    currency_code_type_id integer GENERATED ALWAYS AS (9) STORED NOT NULL
);


ALTER TABLE employee.user_company_contract OWNER TO timesadmin;

--
-- TOC entry 791 (class 1259 OID 89565)
-- Name: user_company_contract_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_company_contract ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_company_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 860 (class 1259 OID 95504)
-- Name: user_company_education; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_company_education (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    type character varying(20) NOT NULL,
    education_level_id integer,
    status_id integer,
    major_id bigint,
    minor_id bigint,
    provider_type_id bigint,
    country_id bigint,
    city text,
    institution_id bigint,
    start_date date,
    end_date date,
    graduation_date date,
    grade_scale_id bigint,
    grade_value text,
    cert_type text,
    cert_name text NOT NULL,
    cert_issuer text,
    cert_issuer_country_id bigint,
    cert_issue_date date,
    cert_expiry_date date,
    cert_id text,
    remarks text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT education_overflow_constraint CHECK (((((type)::text = 'education'::text) AND (education_level_id IS NOT NULL) AND (institution_id IS NOT NULL) AND (start_date IS NOT NULL)) OR (((type)::text = 'certification'::text) AND (cert_issuer IS NOT NULL) AND (cert_issue_date IS NOT NULL))))
);


ALTER TABLE employee.user_company_education OWNER TO timesadmin;

--
-- TOC entry 859 (class 1259 OID 95503)
-- Name: user_company_education_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_company_education ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_company_education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 862 (class 1259 OID 95561)
-- Name: user_company_setting; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_company_setting (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_cpf boolean DEFAULT false,
    is_fwl boolean DEFAULT false,
    is_sdf boolean DEFAULT false,
    is_mso boolean DEFAULT false,
    is_exclude_sdf boolean DEFAULT false,
    is_iras_benefit_in_kind boolean DEFAULT false,
    is_iras_share_option boolean DEFAULT false,
    is_exclude_iras boolean DEFAULT false,
    is_timesheet_access boolean DEFAULT false,
    is_mobile_clocking boolean DEFAULT false,
    is_email_payroll boolean DEFAULT true NOT NULL,
    is_email_leave boolean DEFAULT true,
    is_email_claim boolean DEFAULT true,
    is_email_timesheet boolean DEFAULT true,
    is_email_appraisal boolean DEFAULT true,
    is_email_training boolean DEFAULT true,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    employee_clock_uid text
);


ALTER TABLE employee.user_company_setting OWNER TO timesadmin;

--
-- TOC entry 861 (class 1259 OID 95560)
-- Name: user_company_setting_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_company_setting ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_company_setting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 772 (class 1259 OID 89175)
-- Name: user_regulatory; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_regulatory (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    residency_type employee.residency_type,
    singaporean_or_spr employee.singaporean_or_spr,
    is_voluntary_contribution boolean DEFAULT false NOT NULL,
    voluntary_rate_type employee.voluntary_rate_type,
    additional_employee_rate numeric(5,2),
    additional_employer_rate numeric(5,2),
    ff_fg_option employee.ff_fg_option,
    cpf_full_rate_approve_date date,
    is_taxable_contribution boolean DEFAULT false NOT NULL,
    is_mso_scheme boolean DEFAULT false NOT NULL,
    is_cap_at_max_ceiling boolean DEFAULT false NOT NULL,
    is_pmbs_scheme boolean DEFAULT false NOT NULL,
    community_fund_code1 character varying(10),
    community_fund_code2 character varying(10),
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    commfund1_opted_in boolean,
    commfund1_absorbed_by_company boolean,
    commfund1_need_topup boolean,
    commfund2_opted_in boolean,
    commfund2_absorbed_by_company boolean,
    commfund2_need_topup boolean,
    custom_cpf_profile_id bigint,
    nric_no bytea,
    cpf_account_no bytea,
    CONSTRAINT community_fund_code1_constraint CHECK (((community_fund_code1 IS NULL) OR ((community_fund_code1 IS NOT NULL) AND (commfund1_opted_in IS NOT NULL) AND (commfund1_absorbed_by_company IS NOT NULL) AND (commfund1_need_topup IS NOT NULL)))),
    CONSTRAINT community_fund_code2_constraint CHECK (((community_fund_code2 IS NULL) OR ((community_fund_code2 IS NOT NULL) AND (commfund2_opted_in IS NOT NULL) AND (commfund2_absorbed_by_company IS NOT NULL) AND (commfund2_need_topup IS NOT NULL))))
);


ALTER TABLE employee.user_regulatory OWNER TO timesadmin;

--
-- TOC entry 879 (class 1259 OID 98220)
-- Name: user_regulatory_commfund_topup; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_regulatory_commfund_topup (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id integer NOT NULL,
    company_id integer NOT NULL,
    type_id integer NOT NULL,
    commfund_number integer NOT NULL,
    commfund_code text NOT NULL,
    effective_period date NOT NULL,
    end_period date,
    amount numeric(20,2) NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE employee.user_regulatory_commfund_topup OWNER TO timesadmin;

--
-- TOC entry 878 (class 1259 OID 98219)
-- Name: user_regulatory_commfund_topup_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_regulatory_commfund_topup ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_regulatory_commfund_topup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 771 (class 1259 OID 89174)
-- Name: user_regulatory_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_regulatory ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_regulatory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 774 (class 1259 OID 89199)
-- Name: user_regulatory_spr; Type: TABLE; Schema: employee; Owner: timesadmin
--

CREATE TABLE employee.user_regulatory_spr (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    regulatory_id bigint NOT NULL,
    spr_approved_date date NOT NULL,
    spr_withdrawal_date date,
    is_spr_gen2 boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    CONSTRAINT chk_spr_withdrawal_after_approved CHECK (((spr_withdrawal_date IS NULL) OR (spr_withdrawal_date > spr_approved_date)))
);


ALTER TABLE employee.user_regulatory_spr OWNER TO timesadmin;

--
-- TOC entry 773 (class 1259 OID 89198)
-- Name: user_regulatory_spr_id_seq; Type: SEQUENCE; Schema: employee; Owner: timesadmin
--

ALTER TABLE employee.user_regulatory_spr ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME employee.user_regulatory_spr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 701 (class 1259 OID 73746)
-- Name: lk_leave_type; Type: TABLE; Schema: leave; Owner: timesadmin
--

CREATE TABLE leave.lk_leave_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE leave.lk_leave_type OWNER TO timesadmin;

--
-- TOC entry 700 (class 1259 OID 73745)
-- Name: lk_leave_type_id_seq; Type: SEQUENCE; Schema: leave; Owner: timesadmin
--

ALTER TABLE leave.lk_leave_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME leave.lk_leave_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 634 (class 1259 OID 62476)
-- Name: encashment_policy; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.encashment_policy (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    encashment_method_id bigint DEFAULT 1 NOT NULL,
    encashment_code_id bigint,
    encashment_deduction_code_id bigint,
    rounding_formula_id bigint DEFAULT 1 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE payroll.encashment_policy OWNER TO timesadmin;

--
-- TOC entry 633 (class 1259 OID 62475)
-- Name: encashment_policy_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.encashment_policy ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.encashment_policy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 632 (class 1259 OID 62461)
-- Name: lk_encashment_method; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.lk_encashment_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE payroll.lk_encashment_method OWNER TO timesadmin;

--
-- TOC entry 631 (class 1259 OID 62460)
-- Name: lk_encashment_method_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.lk_encashment_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.lk_encashment_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 624 (class 1259 OID 62244)
-- Name: lk_mvc_method; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.lk_mvc_method (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE payroll.lk_mvc_method OWNER TO timesadmin;

--
-- TOC entry 623 (class 1259 OID 62243)
-- Name: lk_mvc_method_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.lk_mvc_method ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.lk_mvc_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 626 (class 1259 OID 62259)
-- Name: lk_mvc_scheme; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.lk_mvc_scheme (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE payroll.lk_mvc_scheme OWNER TO timesadmin;

--
-- TOC entry 625 (class 1259 OID 62258)
-- Name: lk_mvc_scheme_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.lk_mvc_scheme ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.lk_mvc_scheme_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 915 (class 1259 OID 107063)
-- Name: lk_pay_run_status; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.lk_pay_run_status (
    id integer NOT NULL,
    name text NOT NULL,
    description text,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.lk_pay_run_status OWNER TO timesadmin;

--
-- TOC entry 914 (class 1259 OID 107062)
-- Name: lk_pay_run_status_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.lk_pay_run_status ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.lk_pay_run_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 844 (class 1259 OID 93841)
-- Name: lk_payroll_cycle; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.lk_payroll_cycle (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    description text,
    short_code text
);


ALTER TABLE payroll.lk_payroll_cycle OWNER TO timesadmin;

--
-- TOC entry 843 (class 1259 OID 93840)
-- Name: lk_payroll_cycle_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.lk_payroll_cycle ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.lk_payroll_cycle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 683 (class 1259 OID 70210)
-- Name: mso; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.mso (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    is_mso boolean,
    mso_account_no text,
    max_amount_ow numeric,
    max_amount_aw numeric,
    pmbs_percent numeric,
    pmbs_max_cap numeric,
    rounding_formula_id bigint DEFAULT 3 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE payroll.mso OWNER TO timesadmin;

--
-- TOC entry 682 (class 1259 OID 70209)
-- Name: mso_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.mso ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.mso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 628 (class 1259 OID 62317)
-- Name: mvc; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.mvc (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    mvc_schema_id bigint DEFAULT 1 NOT NULL,
    mvc_method_id bigint DEFAULT 1 NOT NULL,
    default_mvc_amount numeric(18,6) DEFAULT 10.00,
    mvc_cap_amount numeric(18,6) DEFAULT 0.00,
    rounding_formula_id bigint DEFAULT 4 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE payroll.mvc OWNER TO timesadmin;

--
-- TOC entry 627 (class 1259 OID 62316)
-- Name: mvc_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.mvc ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.mvc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 924 (class 1259 OID 108135)
-- Name: pay_period; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.pay_period (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text DEFAULT to_char((CURRENT_DATE)::timestamp with time zone, 'Mon YYYY'::text) NOT NULL,
    value text DEFAULT to_char((CURRENT_DATE)::timestamp with time zone, 'MM/YYYY'::text) NOT NULL,
    is_lock boolean DEFAULT false NOT NULL,
    created_by text DEFAULT 'PG_Cron'::text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    company_id bigint NOT NULL
);


ALTER TABLE payroll.pay_period OWNER TO timesadmin;

--
-- TOC entry 927 (class 1259 OID 110905)
-- Name: pay_period_contribution; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.pay_period_contribution (
    id bigint NOT NULL,
    pay_period_id bigint NOT NULL,
    user_id bigint NOT NULL,
    ow_amount numeric DEFAULT 0 NOT NULL,
    aw_amount numeric DEFAULT 0 NOT NULL,
    cdac_amount numeric DEFAULT 0 NOT NULL,
    sdl_amount numeric DEFAULT 0 NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    udpated_by text,
    updated_on timestamp without time zone,
    mbmf_amount numeric DEFAULT 0 NOT NULL,
    sinda_amount numeric DEFAULT 0 NOT NULL,
    ecf_amount numeric DEFAULT 0 NOT NULL,
    company_id bigint NOT NULL
);


ALTER TABLE payroll.pay_period_contribution OWNER TO timesadmin;

--
-- TOC entry 926 (class 1259 OID 110904)
-- Name: pay_period_contribution_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.pay_period_contribution ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.pay_period_contribution_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 923 (class 1259 OID 108134)
-- Name: pay_period_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.pay_period ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.pay_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 919 (class 1259 OID 107137)
-- Name: pay_record; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.pay_record (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    contract_id bigint NOT NULL,
    designation text,
    department text,
    basic_salary numeric DEFAULT 0,
    total_allowance numeric DEFAULT 0,
    total_deduction numeric DEFAULT 0,
    total_cpf numeric DEFAULT 0,
    total_payout numeric DEFAULT 0,
    data_processed json,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_by text,
    updated_on timestamp without time zone,
    pay_run_id bigint NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    note text,
    is_new_hire boolean DEFAULT false NOT NULL,
    is_resignee boolean DEFAULT false NOT NULL
);


ALTER TABLE payroll.pay_record OWNER TO timesadmin;

--
-- TOC entry 918 (class 1259 OID 107136)
-- Name: pay_record_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.pay_record ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.pay_record_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 925 (class 1259 OID 110708)
-- Name: pay_record_modification; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.pay_record_modification (
    pay_record_id bigint NOT NULL,
    modification json NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_by text,
    updated_on timestamp without time zone
);


ALTER TABLE payroll.pay_record_modification OWNER TO timesadmin;

--
-- TOC entry 917 (class 1259 OID 107088)
-- Name: pay_run; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.pay_run (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    pay_run_date timestamp without time zone NOT NULL,
    pay_cycle_id integer NOT NULL,
    created_by text DEFAULT 'System'::text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_by text,
    updated_on timestamp without time zone,
    description text,
    pay_period text DEFAULT to_char((CURRENT_DATE)::timestamp with time zone, 'MM/YYYY'::text) NOT NULL,
    pay_period_id bigint,
    is_lock boolean DEFAULT false NOT NULL
);


ALTER TABLE payroll.pay_run OWNER TO timesadmin;

--
-- TOC entry 916 (class 1259 OID 107087)
-- Name: pay_run_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.pay_run ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.pay_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 638 (class 1259 OID 62870)
-- Name: rounding_formula; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.rounding_formula (
    id bigint NOT NULL,
    company_id bigint,
    name text NOT NULL,
    formula jsonb[],
    customise_type_code text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    uid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE payroll.rounding_formula OWNER TO timesadmin;

--
-- TOC entry 637 (class 1259 OID 62869)
-- Name: rounding_formula_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.rounding_formula ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME payroll.rounding_formula_id_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 581 (class 1259 OID 57624)
-- Name: sg_cpf_max_formula; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.sg_cpf_max_formula (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE payroll.sg_cpf_max_formula OWNER TO timesadmin;

--
-- TOC entry 580 (class 1259 OID 57623)
-- Name: sg_cpf_max_formula_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.sg_cpf_max_formula ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME payroll.sg_cpf_max_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 583 (class 1259 OID 57633)
-- Name: sg_payroll_settings; Type: TABLE; Schema: payroll; Owner: timesadmin
--

CREATE TABLE payroll.sg_payroll_settings (
    id integer NOT NULL,
    company_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    cpf_max_formula_id bigint DEFAULT 1 NOT NULL,
    auto_deduct_fwl_levy_if_npl_absent boolean DEFAULT false NOT NULL,
    absorbed_by_company boolean DEFAULT false NOT NULL,
    disable_baot boolean DEFAULT false NOT NULL,
    bonus_factor numeric DEFAULT 0,
    is_weekly_payroll boolean DEFAULT false NOT NULL,
    is_union boolean DEFAULT false NOT NULL,
    is_mvc boolean DEFAULT false NOT NULL,
    is_mso boolean DEFAULT false NOT NULL,
    mid_month_subject_to_cpf boolean DEFAULT true NOT NULL,
    mid_month_cpf_wage_times_factor_2 boolean DEFAULT true NOT NULL,
    mid_month_subject_to_com_fund boolean DEFAULT true NOT NULL,
    mid_month_subject_to_sdf boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    mid_month_enabled boolean DEFAULT false NOT NULL
);


ALTER TABLE payroll.sg_payroll_settings OWNER TO timesadmin;

--
-- TOC entry 582 (class 1259 OID 57632)
-- Name: sg_payroll_settings_id_seq; Type: SEQUENCE; Schema: payroll; Owner: timesadmin
--

ALTER TABLE payroll.sg_payroll_settings ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME payroll.sg_payroll_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 235 (class 1259 OID 25821)
-- Name: address; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.address (
    id integer NOT NULL,
    addr1 character varying(50),
    addr2 character varying(50),
    addr3 character varying(50),
    addr4 character varying(50),
    postal_code character varying(50),
    country_id integer,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.address OWNER TO timesadmin;

--
-- TOC entry 236 (class 1259 OID 25824)
-- Name: address_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.address ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 237 (class 1259 OID 25825)
-- Name: address_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.address_info (
    id integer NOT NULL,
    address_id integer,
    address_type_id integer,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.address_info OWNER TO timesadmin;

--
-- TOC entry 238 (class 1259 OID 25828)
-- Name: address_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.address_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.address_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 25829)
-- Name: address_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.address_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    apply_to_id integer,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.address_type OWNER TO timesadmin;

--
-- TOC entry 240 (class 1259 OID 25832)
-- Name: address_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.address_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.address_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 435 (class 1259 OID 31375)
-- Name: application_logs; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.application_logs (
    "Message" text,
    "MessageTemplate" text,
    "Level" integer,
    "Timestamp" timestamp with time zone,
    "Exception" text,
    "LogEvent" jsonb
);


ALTER TABLE public.application_logs OWNER TO timesadmin;

--
-- TOC entry 241 (class 1259 OID 25833)
-- Name: apply_to; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.apply_to (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    description character varying(250),
    parent_apply_to_id integer,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.apply_to OWNER TO timesadmin;

--
-- TOC entry 242 (class 1259 OID 25836)
-- Name: apply_to_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.apply_to ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.apply_to_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 243 (class 1259 OID 25837)
-- Name: appraisal; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.appraisal (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.appraisal OWNER TO timesadmin;

--
-- TOC entry 244 (class 1259 OID 25840)
-- Name: appraisal_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.appraisal ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.appraisal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 245 (class 1259 OID 25841)
-- Name: approval_status; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.approval_status (
    id integer NOT NULL,
    profile_config_id integer,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.approval_status OWNER TO timesadmin;

--
-- TOC entry 246 (class 1259 OID 25844)
-- Name: approval_status_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.approval_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.approval_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 534 (class 1259 OID 49457)
-- Name: audit_log; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    log_event text NOT NULL,
    payload json,
    status_code integer,
    entity_type text,
    remarks text,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text
);


ALTER TABLE public.audit_log OWNER TO timesadmin;

--
-- TOC entry 533 (class 1259 OID 49456)
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 247 (class 1259 OID 25845)
-- Name: bank; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.bank (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    code character(10) NOT NULL,
    name character varying(50) NOT NULL,
    branch character(10) NOT NULL,
    b_i_c character varying(50),
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.bank OWNER TO timesadmin;

--
-- TOC entry 248 (class 1259 OID 25848)
-- Name: bank_address_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.bank_address_info (
    id integer NOT NULL,
    bank_id integer NOT NULL,
    address_info_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.bank_address_info OWNER TO timesadmin;

--
-- TOC entry 249 (class 1259 OID 25851)
-- Name: bank_address_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.bank_address_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bank_address_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 250 (class 1259 OID 25852)
-- Name: bank_contact_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.bank_contact_info (
    id integer NOT NULL,
    bank_id integer NOT NULL,
    contact_info_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.bank_contact_info OWNER TO timesadmin;

--
-- TOC entry 251 (class 1259 OID 25855)
-- Name: bank_contact_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.bank_contact_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bank_contact_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 252 (class 1259 OID 25856)
-- Name: bank_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.bank ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 253 (class 1259 OID 25857)
-- Name: blood_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.blood_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.blood_type OWNER TO timesadmin;

--
-- TOC entry 254 (class 1259 OID 25860)
-- Name: blood_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.blood_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.blood_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 255 (class 1259 OID 25861)
-- Name: calculate_by_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.calculate_by_type (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    name character varying(50),
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.calculate_by_type OWNER TO timesadmin;

--
-- TOC entry 256 (class 1259 OID 25864)
-- Name: calculate_by_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.calculate_by_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.calculate_by_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 257 (class 1259 OID 25865)
-- Name: category; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.category (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.category OWNER TO timesadmin;

--
-- TOC entry 258 (class 1259 OID 25868)
-- Name: category_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 259 (class 1259 OID 25869)
-- Name: citizenship; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.citizenship (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.citizenship OWNER TO timesadmin;

--
-- TOC entry 260 (class 1259 OID 25872)
-- Name: citizenship_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.citizenship ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.citizenship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 261 (class 1259 OID 25873)
-- Name: classification; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.classification (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.classification OWNER TO timesadmin;

--
-- TOC entry 262 (class 1259 OID 25876)
-- Name: classification_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.classification ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.classification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 263 (class 1259 OID 25877)
-- Name: company; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.company (
    id bigint NOT NULL,
    parent_company_id integer,
    uid uuid,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    registration_number character varying(50),
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.company OWNER TO timesadmin;

--
-- TOC entry 264 (class 1259 OID 25882)
-- Name: company_address_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.company_address_info (
    id integer NOT NULL,
    company_id integer NOT NULL,
    address_info_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.company_address_info OWNER TO timesadmin;

--
-- TOC entry 265 (class 1259 OID 25885)
-- Name: company_address_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.company_address_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.company_address_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 266 (class 1259 OID 25886)
-- Name: company_bank; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.company_bank (
    id integer NOT NULL,
    company_id integer NOT NULL,
    bank_id integer NOT NULL,
    account character varying(50) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.company_bank OWNER TO timesadmin;

--
-- TOC entry 267 (class 1259 OID 25889)
-- Name: company_bank_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.company_bank ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.company_bank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 268 (class 1259 OID 25890)
-- Name: company_contact_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.company_contact_info (
    id integer NOT NULL,
    company_id integer NOT NULL,
    contact_info_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.company_contact_info OWNER TO timesadmin;

--
-- TOC entry 269 (class 1259 OID 25893)
-- Name: company_contact_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.company_contact_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.company_contact_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 270 (class 1259 OID 25894)
-- Name: company_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.company ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.company_id_seq
    START WITH 753
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 271 (class 1259 OID 25895)
-- Name: company_statutory; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.company_statutory (
    id integer NOT NULL,
    company_id integer NOT NULL,
    statutory_id integer NOT NULL,
    effective_date timestamp without time zone,
    account_number character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.company_statutory OWNER TO timesadmin;

--
-- TOC entry 272 (class 1259 OID 25898)
-- Name: company_statutory_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.company_statutory ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.company_statutory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 273 (class 1259 OID 25899)
-- Name: computation_based_on_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.computation_based_on_type (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    name character varying(50),
    description character varying(250),
    apply_to_id integer,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.computation_based_on_type OWNER TO timesadmin;

--
-- TOC entry 274 (class 1259 OID 25902)
-- Name: computation_based_on_type_formula; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.computation_based_on_type_formula (
    id integer NOT NULL,
    profile_config_id integer,
    computation_based_on_type_id integer NOT NULL,
    formula character varying(250) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.computation_based_on_type_formula OWNER TO timesadmin;

--
-- TOC entry 275 (class 1259 OID 25905)
-- Name: computation_based_on_type_formula_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.computation_based_on_type_formula ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.computation_based_on_type_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 276 (class 1259 OID 25906)
-- Name: computation_based_on_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.computation_based_on_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.computation_based_on_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 277 (class 1259 OID 25907)
-- Name: contact; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.contact (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    first_name character varying(50),
    middle_name character varying(50),
    last_name character varying(50),
    alias character varying(50),
    salutation_id integer,
    designation character varying(50),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.contact OWNER TO timesadmin;

--
-- TOC entry 278 (class 1259 OID 25910)
-- Name: contact_address_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.contact_address_info (
    id integer NOT NULL,
    contact_id integer NOT NULL,
    address_info_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.contact_address_info OWNER TO timesadmin;

--
-- TOC entry 279 (class 1259 OID 25913)
-- Name: contact_address_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.contact_address_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contact_address_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 280 (class 1259 OID 25914)
-- Name: contact_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.contact ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 281 (class 1259 OID 25915)
-- Name: contact_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.contact_info (
    id integer NOT NULL,
    contact_id integer,
    contact_type_id integer NOT NULL,
    value character varying(250) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.contact_info OWNER TO timesadmin;

--
-- TOC entry 282 (class 1259 OID 25918)
-- Name: contact_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.contact_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contact_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 283 (class 1259 OID 25919)
-- Name: contact_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.contact_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.contact_type OWNER TO timesadmin;

--
-- TOC entry 284 (class 1259 OID 25922)
-- Name: contact_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.contact_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contact_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 285 (class 1259 OID 25923)
-- Name: cost_centre; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.cost_centre (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.cost_centre OWNER TO timesadmin;

--
-- TOC entry 286 (class 1259 OID 25926)
-- Name: cost_centre_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.cost_centre ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cost_centre_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 287 (class 1259 OID 25927)
-- Name: country; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.country (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.country OWNER TO timesadmin;

--
-- TOC entry 288 (class 1259 OID 25930)
-- Name: country_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.country ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.country_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 289 (class 1259 OID 25931)
-- Name: currency; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.currency (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.currency OWNER TO timesadmin;

--
-- TOC entry 290 (class 1259 OID 25934)
-- Name: currency_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.currency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.currency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 291 (class 1259 OID 25935)
-- Name: department; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.department (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.department OWNER TO timesadmin;

--
-- TOC entry 292 (class 1259 OID 25938)
-- Name: department_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.department ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 293 (class 1259 OID 25939)
-- Name: division; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.division (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.division OWNER TO timesadmin;

--
-- TOC entry 294 (class 1259 OID 25942)
-- Name: division_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.division ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.division_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 295 (class 1259 OID 25943)
-- Name: education; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.education (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.education OWNER TO timesadmin;

--
-- TOC entry 296 (class 1259 OID 25946)
-- Name: education_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.education ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 297 (class 1259 OID 25947)
-- Name: employee; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    first_name character varying(50),
    middle_name character varying(50),
    last_name character varying(50),
    alias character varying(50),
    salutation_id integer,
    race_id integer,
    religion_id integer,
    education_id integer,
    marital_status_id integer,
    blood_type_id integer,
    nationality_id integer,
    citizenship_id integer,
    d_o_b timestamp without time zone NOT NULL,
    gender character varying(1) NOT NULL,
    hired_date timestamp without time zone,
    pay_effective_date timestamp without time zone,
    created_on timestamp without time zone,
    created_by character varying(50),
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee OWNER TO timesadmin;

--
-- TOC entry 298 (class 1259 OID 25950)
-- Name: employee_bank; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_bank (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    bank_id integer NOT NULL,
    account character varying(50) NOT NULL,
    percentage numeric(18,0) NOT NULL,
    fixed_amount numeric(18,0) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_bank OWNER TO timesadmin;

--
-- TOC entry 299 (class 1259 OID 25953)
-- Name: employee_bank_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_bank ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_bank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 300 (class 1259 OID 25954)
-- Name: employee_calendar; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_calendar (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    work_code_id integer NOT NULL,
    work_date timestamp without time zone NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_calendar OWNER TO timesadmin;

--
-- TOC entry 301 (class 1259 OID 25957)
-- Name: employee_calendar_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_calendar ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_calendar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 302 (class 1259 OID 25958)
-- Name: employee_contact_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_contact_info (
    id integer NOT NULL,
    employee_id integer,
    contact_type_id integer NOT NULL,
    value character varying(250) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_contact_info OWNER TO timesadmin;

--
-- TOC entry 303 (class 1259 OID 25961)
-- Name: employee_contact_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_contact_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_contact_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 304 (class 1259 OID 25962)
-- Name: employee_cost_centre_allocation; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_cost_centre_allocation (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    pay_period_id integer NOT NULL,
    pay_cycle_id integer NOT NULL,
    cost_centre_id integer NOT NULL,
    department_id integer NOT NULL,
    percentage numeric(18,2),
    work_hours numeric(18,2),
    effective_date timestamp without time zone NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_cost_centre_allocation OWNER TO timesadmin;

--
-- TOC entry 305 (class 1259 OID 25965)
-- Name: employee_cost_centre_allocation_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_cost_centre_allocation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_cost_centre_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 306 (class 1259 OID 25966)
-- Name: employee_employment; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_employment (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    progression_code_id integer,
    department_id integer,
    cost_centre_id integer,
    occupation_id integer,
    section_id integer,
    category_id integer,
    company_id integer,
    job_grade_id integer,
    appraisal_id integer,
    division_id integer,
    job_level_id integer,
    classification_id integer,
    currency_id integer,
    salary_type_id integer,
    basic_salary numeric(18,0),
    progression_date timestamp without time zone NOT NULL,
    effective_date timestamp without time zone NOT NULL,
    remarks character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_employment OWNER TO timesadmin;

--
-- TOC entry 307 (class 1259 OID 25969)
-- Name: employee_employment_approval; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_employment_approval (
    id integer NOT NULL,
    employee_employment_id integer NOT NULL,
    approval_status_id integer NOT NULL,
    approval_date timestamp without time zone NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_employment_approval OWNER TO timesadmin;

--
-- TOC entry 308 (class 1259 OID 25972)
-- Name: employee_employment_approval_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_employment_approval ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_employment_approval_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 309 (class 1259 OID 25973)
-- Name: employee_employment_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_employment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_employment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 310 (class 1259 OID 25974)
-- Name: employee_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 311 (class 1259 OID 25975)
-- Name: employee_identification_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_identification_type (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    identification_type_id integer NOT NULL,
    code character varying(50) NOT NULL,
    issue_date timestamp without time zone NOT NULL,
    expiry_date timestamp without time zone NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_identification_type OWNER TO timesadmin;

--
-- TOC entry 312 (class 1259 OID 25978)
-- Name: employee_identification_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_identification_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_identification_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 313 (class 1259 OID 25979)
-- Name: employee_language; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_language (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    language_id integer NOT NULL,
    spoken boolean,
    written boolean,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_language OWNER TO timesadmin;

--
-- TOC entry 314 (class 1259 OID 25982)
-- Name: employee_language_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_language ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 315 (class 1259 OID 25983)
-- Name: employee_mvc; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_mvc (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    calcuate_by_type_id integer,
    annual_increment numeric(18,2),
    m_v_c_increment numeric(18,2),
    m_v_c_accumulate numeric(18,2),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_mvc OWNER TO timesadmin;

--
-- TOC entry 316 (class 1259 OID 25986)
-- Name: employee_mvc_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_mvc ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_mvc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 317 (class 1259 OID 25987)
-- Name: employee_pay_code_recurrence; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_pay_code_recurrence (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    type character varying(50) NOT NULL,
    currency_id integer NOT NULL,
    fixed_amount numeric(18,2),
    payment_date timestamp without time zone NOT NULL,
    recurrance integer NOT NULL,
    start_date timestamp without time zone NOT NULL,
    end_date timestamp without time zone NOT NULL,
    pay_cycle_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_pay_code_recurrence OWNER TO timesadmin;

--
-- TOC entry 318 (class 1259 OID 25990)
-- Name: employee_pay_code_recurrence_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_pay_code_recurrence ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_pay_code_recurrence_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 319 (class 1259 OID 25991)
-- Name: employee_pay_group; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_pay_group (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    pay_group_id integer NOT NULL,
    effective_date timestamp without time zone NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_pay_group OWNER TO timesadmin;

--
-- TOC entry 320 (class 1259 OID 25994)
-- Name: employee_pay_group_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_pay_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_pay_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 321 (class 1259 OID 25995)
-- Name: employee_pay_type_setting; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_pay_type_setting (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    pay_type_id integer NOT NULL,
    bonus_factor character varying(50),
    daily_rate_formula_id integer,
    n_p_l_rate_formula_id integer,
    festival_advance_formula_id integer,
    pay_frequency_id integer,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_pay_type_setting OWNER TO timesadmin;

--
-- TOC entry 322 (class 1259 OID 25998)
-- Name: employee_pay_type_setting_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_pay_type_setting ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_pay_type_setting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 323 (class 1259 OID 25999)
-- Name: employee_statutory; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_statutory (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    statutory_id integer NOT NULL,
    approval_date timestamp without time zone,
    effective_date timestamp without time zone,
    cancellation_date timestamp without time zone,
    remarks character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_statutory OWNER TO timesadmin;

--
-- TOC entry 324 (class 1259 OID 26002)
-- Name: employee_statutory_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_statutory ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_statutory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 325 (class 1259 OID 26003)
-- Name: employee_wage_formula; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_wage_formula (
    id integer NOT NULL,
    pay_record_id integer NOT NULL,
    employee_id integer NOT NULL,
    wage_apply_to_id integer NOT NULL,
    amount numeric(18,0) NOT NULL,
    formula character varying(250) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_wage_formula OWNER TO timesadmin;

--
-- TOC entry 326 (class 1259 OID 26006)
-- Name: employee_wage_formula_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_wage_formula ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_wage_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 327 (class 1259 OID 26007)
-- Name: employee_work_pass; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.employee_work_pass (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    work_pass_id integer NOT NULL,
    code character varying(50) NOT NULL,
    application_date timestamp without time zone,
    issue_date timestamp without time zone,
    expiry_date timestamp without time zone,
    cancellation_date timestamp without time zone,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.employee_work_pass OWNER TO timesadmin;

--
-- TOC entry 328 (class 1259 OID 26010)
-- Name: employee_work_pass_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.employee_work_pass ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_work_pass_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 329 (class 1259 OID 26011)
-- Name: formula_expression; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.formula_expression (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    expression text,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.formula_expression OWNER TO timesadmin;

--
-- TOC entry 330 (class 1259 OID 26016)
-- Name: formula_expression_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.formula_expression ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.formula_expression_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 570 (class 1259 OID 56187)
-- Name: guided_onboarding; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.guided_onboarding (
    code character varying(255) NOT NULL,
    content_json jsonb NOT NULL
);


ALTER TABLE public.guided_onboarding OWNER TO timesadmin;

--
-- TOC entry 571 (class 1259 OID 56194)
-- Name: guided_onboarding_log; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.guided_onboarding_log (
    user_id integer NOT NULL,
    guided_onboarding_code character varying(255) NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'System'::text NOT NULL
);


ALTER TABLE public.guided_onboarding_log OWNER TO timesadmin;

--
-- TOC entry 331 (class 1259 OID 26017)
-- Name: identification_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.identification_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.identification_type OWNER TO timesadmin;

--
-- TOC entry 332 (class 1259 OID 26020)
-- Name: identification_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.identification_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.identification_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 333 (class 1259 OID 26021)
-- Name: job_grade; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.job_grade (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.job_grade OWNER TO timesadmin;

--
-- TOC entry 334 (class 1259 OID 26024)
-- Name: job_grade_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.job_grade ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.job_grade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 335 (class 1259 OID 26025)
-- Name: job_level; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.job_level (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.job_level OWNER TO timesadmin;

--
-- TOC entry 336 (class 1259 OID 26028)
-- Name: job_level_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.job_level ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.job_level_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 337 (class 1259 OID 26029)
-- Name: language; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.language (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.language OWNER TO timesadmin;

--
-- TOC entry 338 (class 1259 OID 26032)
-- Name: language_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.language ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.language_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 339 (class 1259 OID 26033)
-- Name: leave_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.leave_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.leave_type OWNER TO timesadmin;

--
-- TOC entry 340 (class 1259 OID 26036)
-- Name: leave_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.leave_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.leave_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 434 (class 1259 OID 30569)
-- Name: licensing_plan; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.licensing_plan (
    id bigint NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    allow_add_payroll_admin boolean DEFAULT false NOT NULL,
    allow_coupon_use boolean DEFAULT false NOT NULL,
    allow_priority_support boolean DEFAULT false NOT NULL,
    allow_referral_use boolean DEFAULT false NOT NULL,
    allow_upgrade_active_employee boolean DEFAULT false NOT NULL,
    default_payroll_admin integer DEFAULT 1 NOT NULL,
    effective_date timestamp without time zone,
    min_active_employee integer DEFAULT 1 NOT NULL,
    max_active_employee integer DEFAULT 999999 NOT NULL,
    status_id bigint,
    version numeric
);


ALTER TABLE public.licensing_plan OWNER TO timesadmin;

--
-- TOC entry 433 (class 1259 OID 30568)
-- Name: licensing_plan_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.licensing_plan ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.licensing_plan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 341 (class 1259 OID 26037)
-- Name: marital_status; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.marital_status (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.marital_status OWNER TO timesadmin;

--
-- TOC entry 342 (class 1259 OID 26040)
-- Name: marital_status_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.marital_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.marital_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 343 (class 1259 OID 26041)
-- Name: nationality; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.nationality (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.nationality OWNER TO timesadmin;

--
-- TOC entry 344 (class 1259 OID 26044)
-- Name: nationality_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.nationality ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.nationality_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 345 (class 1259 OID 26045)
-- Name: occupation; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.occupation (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.occupation OWNER TO timesadmin;

--
-- TOC entry 346 (class 1259 OID 26048)
-- Name: occupation_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.occupation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.occupation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 347 (class 1259 OID 26049)
-- Name: pay_batch_employee; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_batch_employee (
    id integer NOT NULL,
    pay_period_id integer NOT NULL,
    pay_cycle_id integer NOT NULL,
    employee_id integer NOT NULL,
    status_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_batch_employee OWNER TO timesadmin;

--
-- TOC entry 348 (class 1259 OID 26052)
-- Name: pay_batch_employee_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_batch_employee ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_batch_employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 349 (class 1259 OID 26053)
-- Name: pay_code; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    description character varying(250),
    statutory_id integer,
    statutory_account_type_id integer,
    unit character(10) NOT NULL,
    factor numeric(18,0),
    tax_group_code character varying(50),
    parent_pay_code_id integer,
    back_pay_pay_code_id integer,
    definition_type_code character(10) NOT NULL,
    is_grp bigint NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code OWNER TO timesadmin;

--
-- TOC entry 350 (class 1259 OID 26056)
-- Name: pay_code_formula; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_formula (
    id integer NOT NULL,
    pay_code_id integer NOT NULL,
    formula_apply_to_id integer,
    formula character varying(250) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_formula OWNER TO timesadmin;

--
-- TOC entry 351 (class 1259 OID 26061)
-- Name: pay_code_formula_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_formula ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 352 (class 1259 OID 26062)
-- Name: pay_code_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 353 (class 1259 OID 26063)
-- Name: pay_code_n_p_l_rate; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_n_p_l_rate (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    is_enable_n_p_l_entry boolean NOT NULL,
    is_enable_n_p_l_hr_entry boolean NOT NULL,
    is_enable_absent_entry boolean NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_n_p_l_rate OWNER TO timesadmin;

--
-- TOC entry 354 (class 1259 OID 26066)
-- Name: pay_code_n_p_l_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_n_p_l_rate ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_n_p_l_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 355 (class 1259 OID 26067)
-- Name: pay_code_n_p_l_rate_range; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_n_p_l_rate_range (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_n_p_l_rate_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    statutory_account_type_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_n_p_l_rate_range OWNER TO timesadmin;

--
-- TOC entry 356 (class 1259 OID 26070)
-- Name: pay_code_n_p_l_rate_range_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_n_p_l_rate_range ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_n_p_l_rate_range_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 357 (class 1259 OID 26071)
-- Name: pay_code_o_t_rate; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_o_t_rate (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    celing_c_b_o_type_id integer NOT NULL,
    round_off_method_id integer NOT NULL,
    rate_setting_c_b_o_type_id integer NOT NULL,
    hours_ceiling integer NOT NULL,
    hours_ceiling_min integer NOT NULL,
    hours_ceiling_max integer NOT NULL,
    is_enable_entry boolean NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_o_t_rate OWNER TO timesadmin;

--
-- TOC entry 358 (class 1259 OID 26074)
-- Name: pay_code_o_t_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_o_t_rate ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_o_t_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 359 (class 1259 OID 26075)
-- Name: pay_code_o_t_rate_range; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_o_t_rate_range (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_o_t_rate_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    factor numeric(18,0),
    c_b_o_type_id integer NOT NULL,
    statutory_account_type_id integer NOT NULL,
    tax_group_code character varying(50),
    is_grp boolean NOT NULL,
    is_npl boolean NOT NULL,
    is_mso boolean NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_o_t_rate_range OWNER TO timesadmin;

--
-- TOC entry 360 (class 1259 OID 26078)
-- Name: pay_code_o_t_rate_range_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_o_t_rate_range ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_o_t_rate_range_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 361 (class 1259 OID 26079)
-- Name: pay_code_prorate_leave_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_prorate_leave_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_prorate_setting_id integer NOT NULL,
    leave_type_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_prorate_leave_type OWNER TO timesadmin;

--
-- TOC entry 362 (class 1259 OID 26082)
-- Name: pay_code_prorate_leave_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_prorate_leave_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_prorate_leave_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 363 (class 1259 OID 26083)
-- Name: pay_code_prorate_setting; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_prorate_setting (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    rate_type_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_prorate_setting OWNER TO timesadmin;

--
-- TOC entry 364 (class 1259 OID 26086)
-- Name: pay_code_prorate_setting_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_prorate_setting ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_prorate_setting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 365 (class 1259 OID 26087)
-- Name: pay_code_r_d_rate; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_r_d_rate (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    is_enable_entry boolean NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_r_d_rate OWNER TO timesadmin;

--
-- TOC entry 366 (class 1259 OID 26090)
-- Name: pay_code_r_d_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_r_d_rate ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_r_d_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 367 (class 1259 OID 26091)
-- Name: pay_code_r_d_rate_range; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_r_d_rate_range (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_r_d_rate_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    factor numeric(18,0),
    c_b_o_type_id integer,
    statutory_account_type_id integer NOT NULL,
    tax_group_code character varying(50),
    is_o_t boolean NOT NULL,
    is_npl boolean NOT NULL,
    is_mso boolean NOT NULL,
    rate_type_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_r_d_rate_range OWNER TO timesadmin;

--
-- TOC entry 368 (class 1259 OID 26094)
-- Name: pay_code_r_d_rate_range_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_r_d_rate_range ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_r_d_rate_range_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 369 (class 1259 OID 26095)
-- Name: pay_code_rate_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_rate_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    rate_type_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_rate_type OWNER TO timesadmin;

--
-- TOC entry 370 (class 1259 OID 26098)
-- Name: pay_code_rate_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_rate_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_rate_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 371 (class 1259 OID 26099)
-- Name: pay_code_s_f_rate; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_s_f_rate (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    is_enable_entry boolean NOT NULL,
    avg_shift_month character varying(50),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_s_f_rate OWNER TO timesadmin;

--
-- TOC entry 372 (class 1259 OID 26102)
-- Name: pay_code_s_f_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_s_f_rate ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_s_f_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 373 (class 1259 OID 26103)
-- Name: pay_code_s_f_rate_range; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_code_s_f_rate_range (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_code_s_f_rate_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    rate numeric(18,0),
    unit character(10) NOT NULL,
    statutory_account_type_id integer NOT NULL,
    tax_group_code character varying(50),
    is_o_t boolean NOT NULL,
    is_grp boolean NOT NULL,
    is_npl boolean NOT NULL,
    is_mso boolean NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_code_s_f_rate_range OWNER TO timesadmin;

--
-- TOC entry 374 (class 1259 OID 26106)
-- Name: pay_code_s_f_rate_range_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_code_s_f_rate_range ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_code_s_f_rate_range_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 375 (class 1259 OID 26107)
-- Name: pay_cycle; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_cycle (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_cycle OWNER TO timesadmin;

--
-- TOC entry 376 (class 1259 OID 26110)
-- Name: pay_cycle_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_cycle ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_cycle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 377 (class 1259 OID 26111)
-- Name: pay_frequency; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_frequency (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    name character varying(50),
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_frequency OWNER TO timesadmin;

--
-- TOC entry 378 (class 1259 OID 26114)
-- Name: pay_frequency_allocation; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_frequency_allocation (
    id integer NOT NULL,
    profile_config_id integer,
    pay_frequency_id integer,
    percentage numeric(18,2),
    fixed_amount numeric(18,2),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_frequency_allocation OWNER TO timesadmin;

--
-- TOC entry 379 (class 1259 OID 26117)
-- Name: pay_frequency_allocation_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_frequency_allocation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_frequency_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 380 (class 1259 OID 26118)
-- Name: pay_frequency_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_frequency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_frequency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 381 (class 1259 OID 26119)
-- Name: pay_group; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_group (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    start_date timestamp without time zone NOT NULL,
    end_date timestamp without time zone NOT NULL,
    day_work_per_week integer NOT NULL,
    hour_work_per_year integer NOT NULL,
    working_hours integer NOT NULL,
    daily_rate_formula_id integer NOT NULL,
    n_p_l_rate_formula_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_group OWNER TO timesadmin;

--
-- TOC entry 382 (class 1259 OID 26122)
-- Name: pay_group_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 383 (class 1259 OID 26123)
-- Name: pay_group_pattern; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_group_pattern (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_group_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_group_pattern OWNER TO timesadmin;

--
-- TOC entry 384 (class 1259 OID 26126)
-- Name: pay_group_pattern_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_group_pattern ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_group_pattern_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 385 (class 1259 OID 26127)
-- Name: pay_group_pattern_info; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_group_pattern_info (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    pay_group_pattern_id integer NOT NULL,
    work_code_id integer NOT NULL,
    sequence integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_group_pattern_info OWNER TO timesadmin;

--
-- TOC entry 386 (class 1259 OID 26130)
-- Name: pay_group_pattern_info_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_group_pattern_info ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_group_pattern_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 387 (class 1259 OID 26131)
-- Name: pay_item; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_item (
    id integer NOT NULL,
    pay_record_id integer NOT NULL,
    pay_code_id integer NOT NULL,
    employee_id integer NOT NULL,
    rate_ee numeric(18,0),
    rate_er numeric(18,0),
    frequency integer NOT NULL,
    amount_ee numeric(18,0),
    amount_er numeric(18,0),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_item OWNER TO timesadmin;

--
-- TOC entry 388 (class 1259 OID 26134)
-- Name: pay_item_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_item ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 389 (class 1259 OID 26135)
-- Name: pay_period; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_period (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    description character varying(250),
    period_year character(10) NOT NULL,
    period_month character(10) NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_period OWNER TO timesadmin;

--
-- TOC entry 390 (class 1259 OID 26138)
-- Name: pay_period_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_period ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 391 (class 1259 OID 26139)
-- Name: pay_record; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_record (
    id integer NOT NULL,
    pay_period_id integer NOT NULL,
    pay_cycle_id integer NOT NULL,
    status_id integer NOT NULL,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50),
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_record OWNER TO timesadmin;

--
-- TOC entry 392 (class 1259 OID 26142)
-- Name: pay_record_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_record ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_record_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 393 (class 1259 OID 26143)
-- Name: pay_record_status; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_record_status (
    id integer NOT NULL,
    profile_config_id integer,
    code character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_record_status OWNER TO timesadmin;

--
-- TOC entry 394 (class 1259 OID 26146)
-- Name: pay_record_status_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_record_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_record_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 395 (class 1259 OID 26147)
-- Name: pay_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.pay_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.pay_type OWNER TO timesadmin;

--
-- TOC entry 396 (class 1259 OID 26150)
-- Name: pay_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.pay_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pay_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 397 (class 1259 OID 26151)
-- Name: progression_code; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.progression_code (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.progression_code OWNER TO timesadmin;

--
-- TOC entry 398 (class 1259 OID 26154)
-- Name: progression_code_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.progression_code ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.progression_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 399 (class 1259 OID 26155)
-- Name: race; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.race (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.race OWNER TO timesadmin;

--
-- TOC entry 400 (class 1259 OID 26158)
-- Name: race_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.race ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.race_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 401 (class 1259 OID 26159)
-- Name: rate_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.rate_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    apply_to_id integer,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.rate_type OWNER TO timesadmin;

--
-- TOC entry 402 (class 1259 OID 26162)
-- Name: rate_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.rate_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.rate_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 403 (class 1259 OID 26163)
-- Name: religion; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.religion (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.religion OWNER TO timesadmin;

--
-- TOC entry 404 (class 1259 OID 26166)
-- Name: religion_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.religion ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.religion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 405 (class 1259 OID 26167)
-- Name: round_off_method; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.round_off_method (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    decimal_place integer,
    code character varying(50),
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.round_off_method OWNER TO timesadmin;

--
-- TOC entry 406 (class 1259 OID 26170)
-- Name: round_off_method_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.round_off_method ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.round_off_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 407 (class 1259 OID 26171)
-- Name: salary_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.salary_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.salary_type OWNER TO timesadmin;

--
-- TOC entry 408 (class 1259 OID 26174)
-- Name: salary_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.salary_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.salary_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 409 (class 1259 OID 26175)
-- Name: salutation; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.salutation (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.salutation OWNER TO timesadmin;

--
-- TOC entry 410 (class 1259 OID 26178)
-- Name: salutation_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.salutation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.salutation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 411 (class 1259 OID 26179)
-- Name: section; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.section (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.section OWNER TO timesadmin;

--
-- TOC entry 412 (class 1259 OID 26182)
-- Name: section_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.section ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.section_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 413 (class 1259 OID 26183)
-- Name: statutory; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.statutory (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.statutory OWNER TO timesadmin;

--
-- TOC entry 414 (class 1259 OID 26186)
-- Name: statutory_account_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.statutory_account_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    statutory_id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.statutory_account_type OWNER TO timesadmin;

--
-- TOC entry 415 (class 1259 OID 26189)
-- Name: statutory_account_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.statutory_account_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.statutory_account_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 416 (class 1259 OID 26190)
-- Name: statutory_class_type; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.statutory_class_type (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    statutory_id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.statutory_class_type OWNER TO timesadmin;

--
-- TOC entry 417 (class 1259 OID 26193)
-- Name: statutory_class_type_c_p_f_rate; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.statutory_class_type_c_p_f_rate (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    statutory_class_type_id integer NOT NULL,
    age_from integer NOT NULL,
    age_to integer NOT NULL,
    gross_wage_from numeric(18,0) NOT NULL,
    gross_wage_to numeric(18,0) NOT NULL,
    formula_ee character varying(250) NOT NULL,
    formula_er character varying(250) NOT NULL,
    start_date timestamp without time zone NOT NULL,
    end_date timestamp without time zone,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.statutory_class_type_c_p_f_rate OWNER TO timesadmin;

--
-- TOC entry 418 (class 1259 OID 26198)
-- Name: statutory_class_type_c_p_f_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.statutory_class_type_c_p_f_rate ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.statutory_class_type_c_p_f_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 419 (class 1259 OID 26199)
-- Name: statutory_class_type_f_w_l_rate; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.statutory_class_type_f_w_l_rate (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    statutory_class_type_id integer NOT NULL,
    rate_type_id integer NOT NULL,
    amount numeric(18,0) NOT NULL,
    start_date timestamp without time zone NOT NULL,
    end_date timestamp without time zone,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.statutory_class_type_f_w_l_rate OWNER TO timesadmin;

--
-- TOC entry 420 (class 1259 OID 26202)
-- Name: statutory_class_type_f_w_l_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.statutory_class_type_f_w_l_rate ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.statutory_class_type_f_w_l_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 421 (class 1259 OID 26203)
-- Name: statutory_class_type_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.statutory_class_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.statutory_class_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 422 (class 1259 OID 26204)
-- Name: statutory_formula; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.statutory_formula (
    id integer NOT NULL,
    statutory_id integer NOT NULL,
    formula character varying(250) NOT NULL,
    created_on timestamp without time zone,
    created_by character varying(50),
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.statutory_formula OWNER TO timesadmin;

--
-- TOC entry 423 (class 1259 OID 26207)
-- Name: statutory_formula_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.statutory_formula ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.statutory_formula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 424 (class 1259 OID 26208)
-- Name: statutory_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.statutory ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.statutory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 425 (class 1259 OID 26209)
-- Name: statutory_rate_table; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.statutory_rate_table (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    statutory_id integer NOT NULL,
    gross_wage_from numeric(18,0) NOT NULL,
    gross_wage_to numeric(18,0) NOT NULL,
    rate numeric(18,0) NOT NULL,
    start_date timestamp without time zone NOT NULL,
    end_date timestamp without time zone,
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.statutory_rate_table OWNER TO timesadmin;

--
-- TOC entry 426 (class 1259 OID 26212)
-- Name: statutory_rate_table_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.statutory_rate_table ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.statutory_rate_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 427 (class 1259 OID 26213)
-- Name: work_code; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.work_code (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.work_code OWNER TO timesadmin;

--
-- TOC entry 428 (class 1259 OID 26216)
-- Name: work_code_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.work_code ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.work_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 429 (class 1259 OID 26217)
-- Name: work_pass; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.work_pass (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.work_pass OWNER TO timesadmin;

--
-- TOC entry 430 (class 1259 OID 26220)
-- Name: work_pass_category; Type: TABLE; Schema: public; Owner: timesadmin
--

CREATE TABLE public.work_pass_category (
    id integer NOT NULL,
    profile_config_id integer NOT NULL,
    work_pass_id integer,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    created_on timestamp without time zone NOT NULL,
    created_by character varying(50) NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50)
);


ALTER TABLE public.work_pass_category OWNER TO timesadmin;

--
-- TOC entry 431 (class 1259 OID 26223)
-- Name: work_pass_category_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.work_pass_category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.work_pass_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 432 (class 1259 OID 26224)
-- Name: work_pass_id_seq; Type: SEQUENCE; Schema: public; Owner: timesadmin
--

ALTER TABLE public.work_pass ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.work_pass_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 555 (class 1259 OID 52290)
-- Name: access_rules; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.access_rules (
    id integer NOT NULL,
    resource text NOT NULL,
    resource_type public.resource_type_enum NOT NULL,
    principle text NOT NULL,
    principle_type public.principle_type_enum NOT NULL,
    user_id integer,
    company_id integer,
    permission text NOT NULL,
    parent_id integer,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    is_active boolean DEFAULT true,
    is_granted boolean DEFAULT false,
    role_id integer,
    CONSTRAINT ck_user_company_only_when_principle_type CHECK (((principle_type <> 'user-company'::public.principle_type_enum) OR ((user_id IS NOT NULL) AND (company_id IS NOT NULL))))
);


ALTER TABLE security.access_rules OWNER TO timesadmin;

--
-- TOC entry 554 (class 1259 OID 52289)
-- Name: access_rules_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.access_rules ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.access_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 766 (class 1259 OID 84145)
-- Name: address_usage_type; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.address_usage_type (
    address_id bigint NOT NULL,
    usage_tag_id bigint NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE security.address_usage_type OWNER TO timesadmin;

--
-- TOC entry 902 (class 1259 OID 102157)
-- Name: application_settings; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.application_settings (
    id integer NOT NULL,
    setting_type text NOT NULL,
    setting_name text NOT NULL,
    setting_value text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.application_settings OWNER TO timesadmin;

--
-- TOC entry 901 (class 1259 OID 102156)
-- Name: application_settings_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.application_settings ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.application_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 784 (class 1259 OID 89489)
-- Name: contract_hr_note; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.contract_hr_note (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    note text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.contract_hr_note OWNER TO timesadmin;

--
-- TOC entry 783 (class 1259 OID 89488)
-- Name: contract_hr_note_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.contract_hr_note ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.contract_hr_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 782 (class 1259 OID 89459)
-- Name: contract_resignation; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.contract_resignation (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id bigint NOT NULL,
    reason_id bigint NOT NULL,
    reason_type_id integer GENERATED ALWAYS AS (24) STORED NOT NULL,
    notice_period integer NOT NULL,
    notice_period_type_id bigint NOT NULL,
    tender_date timestamp without time zone DEFAULT now() NOT NULL,
    resignation_date timestamp without time zone NOT NULL,
    last_payment_date timestamp without time zone NOT NULL,
    last_day_of_work timestamp without time zone NOT NULL,
    is_reemployment boolean DEFAULT false NOT NULL,
    is_leave_review boolean DEFAULT false NOT NULL,
    additional_note text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.contract_resignation OWNER TO timesadmin;

--
-- TOC entry 781 (class 1259 OID 89458)
-- Name: contract_resignation_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.contract_resignation ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.contract_resignation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 890 (class 1259 OID 100513)
-- Name: data_model_field; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.data_model_field (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    data_model_id bigint NOT NULL,
    custom_value jsonb,
    data_type_id bigint NOT NULL,
    db_name text,
    table_name text,
    reference_code text,
    field_key text,
    data_type text,
    value_type text,
    filter_expression text,
    join_clauses text DEFAULT ''::text NOT NULL,
    default_operator text DEFAULT '='::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.data_model_field OWNER TO timesadmin;

--
-- TOC entry 889 (class 1259 OID 100512)
-- Name: data_model_field_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.data_model_field ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.data_model_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 888 (class 1259 OID 100491)
-- Name: data_security_rules; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.data_security_rules (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id bigint,
    user_id bigint,
    name text NOT NULL,
    description text,
    rules jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    module_id integer[],
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.data_security_rules OWNER TO timesadmin;

--
-- TOC entry 887 (class 1259 OID 100490)
-- Name: data_security_rules_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.data_security_rules ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.data_security_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 671 (class 1259 OID 65611)
-- Name: disabled_roles; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.disabled_roles (
    role_id bigint NOT NULL,
    disabled_role_id bigint NOT NULL
);


ALTER TABLE security.disabled_roles OWNER TO timesadmin;

--
-- TOC entry 545 (class 1259 OID 52164)
-- Name: feature; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.feature (
    id integer NOT NULL,
    function_id integer,
    code character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    sort_order integer
);


ALTER TABLE security.feature OWNER TO timesadmin;

--
-- TOC entry 904 (class 1259 OID 102502)
-- Name: feature_group; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.feature_group (
    id integer NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    sort_order integer
);


ALTER TABLE security.feature_group OWNER TO timesadmin;

--
-- TOC entry 903 (class 1259 OID 102501)
-- Name: feature_group_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.feature_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.feature_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 544 (class 1259 OID 52163)
-- Name: feature_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.feature ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 550 (class 1259 OID 52197)
-- Name: feature_permission; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.feature_permission (
    feature_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE security.feature_permission OWNER TO timesadmin;

--
-- TOC entry 547 (class 1259 OID 52177)
-- Name: field; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.field (
    id integer NOT NULL,
    feature_id integer,
    code character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    description text
);


ALTER TABLE security.field OWNER TO timesadmin;

--
-- TOC entry 546 (class 1259 OID 52176)
-- Name: field_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.field ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 551 (class 1259 OID 52212)
-- Name: field_permission; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.field_permission (
    field_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE security.field_permission OWNER TO timesadmin;

--
-- TOC entry 543 (class 1259 OID 52136)
-- Name: function; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.function (
    id integer NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    licensing_plan_module_id integer,
    description text,
    sort_order integer,
    feature_group_id integer
);


ALTER TABLE security.function OWNER TO timesadmin;

--
-- TOC entry 542 (class 1259 OID 52135)
-- Name: function_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.function ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.function_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 673 (class 1259 OID 65671)
-- Name: function_permission; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.function_permission (
    function_id bigint NOT NULL,
    permission_id bigint NOT NULL
);


ALTER TABLE security.function_permission OWNER TO timesadmin;

--
-- TOC entry 559 (class 1259 OID 52415)
-- Name: left_menu_item; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.left_menu_item (
    module_code text NOT NULL,
    menu_item text NOT NULL,
    resource_code text
);


ALTER TABLE security.left_menu_item OWNER TO timesadmin;

--
-- TOC entry 907 (class 1259 OID 104080)
-- Name: link_expiry_details; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.link_expiry_details (
    id uuid NOT NULL,
    user_id bigint NOT NULL,
    purpose character varying(100) NOT NULL,
    redirect_url text NOT NULL,
    expires_on timestamp with time zone NOT NULL,
    created_on timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying(255)
);


ALTER TABLE security.link_expiry_details OWNER TO timesadmin;

--
-- TOC entry 765 (class 1259 OID 84098)
-- Name: lk_address_type; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.lk_address_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE security.lk_address_type OWNER TO timesadmin;

--
-- TOC entry 764 (class 1259 OID 84097)
-- Name: lk_address_type_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.lk_address_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.lk_address_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 886 (class 1259 OID 100481)
-- Name: lk_data_field_data_type; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.lk_data_field_data_type (
    id bigint NOT NULL,
    name text NOT NULL,
    operator_id integer[] NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE security.lk_data_field_data_type OWNER TO timesadmin;

--
-- TOC entry 885 (class 1259 OID 100480)
-- Name: lk_data_field_data_type_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.lk_data_field_data_type ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.lk_data_field_data_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 893 (class 1259 OID 101403)
-- Name: lk_data_model; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.lk_data_model (
    id bigint NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    description text,
    is_default boolean,
    sort_order integer
);


ALTER TABLE security.lk_data_model OWNER TO timesadmin;

--
-- TOC entry 894 (class 1259 OID 101410)
-- Name: lk_data_model_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.lk_data_model ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.lk_data_model_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 884 (class 1259 OID 100460)
-- Name: lk_query_operator; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.lk_query_operator (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    value text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE security.lk_query_operator OWNER TO timesadmin;

--
-- TOC entry 883 (class 1259 OID 100459)
-- Name: lk_query_operator_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.lk_query_operator ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.lk_query_operator_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 780 (class 1259 OID 89386)
-- Name: lk_service_grade; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.lk_service_grade (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE security.lk_service_grade OWNER TO timesadmin;

--
-- TOC entry 779 (class 1259 OID 89385)
-- Name: lk_service_grade_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.lk_service_grade ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.lk_service_grade_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 763 (class 1259 OID 84087)
-- Name: lk_usage_tag; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.lk_usage_tag (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text
);


ALTER TABLE security.lk_usage_tag OWNER TO timesadmin;

--
-- TOC entry 762 (class 1259 OID 84086)
-- Name: lk_usage_tag_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.lk_usage_tag ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.lk_usage_tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 900 (class 1259 OID 101505)
-- Name: mobile_secret_key; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.mobile_secret_key (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    secret_key text NOT NULL,
    expiry_date timestamp without time zone,
    login_count bigint DEFAULT 0 NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    access_url text NOT NULL
);


ALTER TABLE security.mobile_secret_key OWNER TO timesadmin;

--
-- TOC entry 899 (class 1259 OID 101504)
-- Name: mobile_secret_key_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.mobile_secret_key ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.mobile_secret_key_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 558 (class 1259 OID 52402)
-- Name: notification_log; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.notification_log (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id integer NOT NULL,
    entity_id bigint,
    entity text DEFAULT 'Other'::text NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'System'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    is_persist boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    type text DEFAULT 'information'::text NOT NULL
);


ALTER TABLE security.notification_log OWNER TO timesadmin;

--
-- TOC entry 557 (class 1259 OID 52401)
-- Name: notification_log_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.notification_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.notification_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 761 (class 1259 OID 84018)
-- Name: other_access; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.other_access (
    id integer NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(100) NOT NULL,
    description text NOT NULL
);


ALTER TABLE security.other_access OWNER TO timesadmin;

--
-- TOC entry 760 (class 1259 OID 84017)
-- Name: other_access_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.other_access ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.other_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 906 (class 1259 OID 103454)
-- Name: password_reset_code; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.password_reset_code (
    id bigint NOT NULL,
    target_id uuid NOT NULL,
    purpose character varying(100) NOT NULL,
    token character varying(512) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_on timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying(255) NOT NULL,
    updated_on timestamp with time zone,
    updated_by character varying(255)
);


ALTER TABLE security.password_reset_code OWNER TO timesadmin;

--
-- TOC entry 905 (class 1259 OID 103453)
-- Name: password_reset_code_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

CREATE SEQUENCE security.password_reset_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE security.password_reset_code_id_seq OWNER TO timesadmin;

--
-- TOC entry 8213 (class 0 OID 0)
-- Dependencies: 905
-- Name: password_reset_code_id_seq; Type: SEQUENCE OWNED BY; Schema: security; Owner: timesadmin
--

ALTER SEQUENCE security.password_reset_code_id_seq OWNED BY security.password_reset_code.id;


--
-- TOC entry 549 (class 1259 OID 52190)
-- Name: permission; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.permission (
    id integer NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(50) NOT NULL,
    heirarchy integer,
    description text
);


ALTER TABLE security.permission OWNER TO timesadmin;

--
-- TOC entry 548 (class 1259 OID 52189)
-- Name: permission_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 922 (class 1259 OID 107425)
-- Name: privacy_security_rule_employees; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.privacy_security_rule_employees (
    rule_id integer NOT NULL,
    target_user_id integer NOT NULL,
    permission character varying(32) NOT NULL,
    CONSTRAINT ck_privacy_security_rule_employees_permission CHECK (((permission)::text = ANY ((ARRAY['follow_career_progression'::character varying, 'salary_view_only'::character varying, 'lock_own_profile'::character varying])::text[])))
);


ALTER TABLE security.privacy_security_rule_employees OWNER TO timesadmin;

--
-- TOC entry 921 (class 1259 OID 107399)
-- Name: privacy_security_rules; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.privacy_security_rules (
    id integer NOT NULL,
    user_id integer NOT NULL,
    company_id integer NOT NULL,
    mode character varying(20) NOT NULL,
    allow_salary_editing boolean DEFAULT false NOT NULL,
    allow_editing_own_salary boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    CONSTRAINT ck_privacy_security_rules_mode CHECK (((mode)::text = ANY ((ARRAY['enable_all'::character varying, 'custom'::character varying])::text[]))),
    CONSTRAINT ck_privacy_security_rules_own_requires_parent CHECK ((allow_salary_editing OR (NOT allow_editing_own_salary))),
    CONSTRAINT ck_privacy_security_rules_toggles_only_enable_all CHECK ((((mode)::text = 'enable_all'::text) OR (NOT (allow_salary_editing OR allow_editing_own_salary))))
);


ALTER TABLE security.privacy_security_rules OWNER TO timesadmin;

--
-- TOC entry 920 (class 1259 OID 107398)
-- Name: privacy_security_rules_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.privacy_security_rules ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.privacy_security_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 677 (class 1259 OID 66839)
-- Name: rate_limit_log; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.rate_limit_log (
    user_id bigint,
    code character varying(255),
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL
);


ALTER TABLE security.rate_limit_log OWNER TO timesadmin;

--
-- TOC entry 676 (class 1259 OID 66834)
-- Name: rate_limit_type; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.rate_limit_type (
    code character varying(255) NOT NULL,
    time_limit_in_seconds integer NOT NULL
);


ALTER TABLE security.rate_limit_type OWNER TO timesadmin;

--
-- TOC entry 541 (class 1259 OID 52125)
-- Name: role; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.role (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    is_admin boolean DEFAULT false NOT NULL,
    is_system_role boolean DEFAULT false NOT NULL,
    hierarchy_level integer,
    can_view_inactive_company boolean DEFAULT false,
    description text,
    is_external_role boolean DEFAULT false
);


ALTER TABLE security.role OWNER TO timesadmin;

--
-- TOC entry 556 (class 1259 OID 52323)
-- Name: role_function; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.role_function (
    function_id integer NOT NULL,
    role_id integer NOT NULL
);


ALTER TABLE security.role_function OWNER TO timesadmin;

--
-- TOC entry 540 (class 1259 OID 52124)
-- Name: role_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.role ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 929 (class 1259 OID 110940)
-- Name: role_transfer_request; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.role_transfer_request (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    from_user_id bigint NOT NULL,
    to_user_id bigint NOT NULL,
    from_role_id integer NOT NULL,
    to_role_id integer NOT NULL,
    expire_on timestamp without time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    updated_by text,
    updated_on timestamp without time zone
);


ALTER TABLE security.role_transfer_request OWNER TO timesadmin;

--
-- TOC entry 928 (class 1259 OID 110939)
-- Name: role_transfer_request_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.role_transfer_request ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.role_transfer_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 768 (class 1259 OID 85551)
-- Name: session_idle_time_old; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.session_idle_time_old (
    id integer NOT NULL,
    grace_period numeric DEFAULT 5,
    idle_timeout numeric DEFAULT 30,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.session_idle_time_old OWNER TO timesadmin;

--
-- TOC entry 767 (class 1259 OID 85550)
-- Name: session_idle_time_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.session_idle_time_old ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.session_idle_time_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 538 (class 1259 OID 52092)
-- Name: user; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security."user" (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid(),
    full_name character varying(150),
    email character varying(100),
    profile_img text,
    is_external boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    ph_number character varying(255),
    last_login_time timestamp with time zone,
    user_status_id integer DEFAULT 1,
    designation character varying(100),
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    is_mfa_enabled boolean DEFAULT true,
    user_enrollment_notification_type security.user_enrollment_notification_type[] DEFAULT ARRAY['Email'::security.user_enrollment_notification_type] NOT NULL,
    access_expiration_date date,
    gender public.gender_type,
    username character varying(255),
    billing_invoice_email_notifications_enabled boolean DEFAULT false NOT NULL
);


ALTER TABLE security."user" OWNER TO timesadmin;

--
-- TOC entry 539 (class 1259 OID 52105)
-- Name: user_company; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.user_company (
    user_id integer NOT NULL,
    company_id integer NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    designation character varying(100),
    is_implicit boolean DEFAULT true NOT NULL
);


ALTER TABLE security.user_company OWNER TO timesadmin;

--
-- TOC entry 552 (class 1259 OID 52227)
-- Name: user_company_role; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.user_company_role (
    user_id integer NOT NULL,
    company_id integer NOT NULL,
    role_id integer NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    user_role_status_id integer DEFAULT 1 NOT NULL
);


ALTER TABLE security.user_company_role OWNER TO timesadmin;

--
-- TOC entry 672 (class 1259 OID 65646)
-- Name: user_company_role_function; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.user_company_role_function (
    user_id bigint NOT NULL,
    company_id bigint NOT NULL,
    role_id bigint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.user_company_role_function OWNER TO timesadmin;

--
-- TOC entry 537 (class 1259 OID 52091)
-- Name: user_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security."user" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 755 (class 1259 OID 79980)
-- Name: user_identity; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.user_identity (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    salutation_id bigint NOT NULL,
    salutation_type_id integer GENERATED ALWAYS AS (7) STORED,
    alias character varying(255),
    native_name character varying(255),
    date_of_birth date NOT NULL,
    place_of_birth_id bigint NOT NULL,
    place_of_birth_type_id integer GENERATED ALWAYS AS (56) STORED,
    martial_status_id bigint NOT NULL,
    martial_status_type_id integer GENERATED ALWAYS AS (6) STORED,
    race_id bigint NOT NULL,
    race_type_id integer GENERATED ALWAYS AS (2) STORED,
    religion_id bigint NOT NULL,
    religion_type_id integer GENERATED ALWAYS AS (3) STORED,
    nationality_id bigint NOT NULL,
    nationality_type_id integer GENERATED ALWAYS AS (57) STORED,
    citizenship_id bigint NOT NULL,
    citizenship_type_id integer GENERATED ALWAYS AS (58) STORED,
    place_of_issue_id bigint,
    place_of_issue_type_id integer GENERATED ALWAYS AS (56) STORED,
    issue_date date,
    expire_date date,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    other_race text,
    other_religion text,
    other_email_address text,
    is_spr boolean DEFAULT false NOT NULL,
    national_id bytea NOT NULL,
    passport_number bytea,
    CONSTRAINT user_identity_check CHECK ((expire_date > issue_date)),
    CONSTRAINT user_identity_other_email_address_check CHECK ((other_email_address ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);


ALTER TABLE security.user_identity OWNER TO timesadmin;

--
-- TOC entry 754 (class 1259 OID 79979)
-- Name: user_identity_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.user_identity ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME security.user_identity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 553 (class 1259 OID 52256)
-- Name: user_role; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.user_role (
    user_id integer NOT NULL,
    role_id integer NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by character varying(50),
    user_role_status_id integer DEFAULT 1 NOT NULL
);


ALTER TABLE security.user_role OWNER TO timesadmin;

--
-- TOC entry 561 (class 1259 OID 55758)
-- Name: user_role_status; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.user_role_status (
    id integer NOT NULL,
    status character varying(255) NOT NULL
);


ALTER TABLE security.user_role_status OWNER TO timesadmin;

--
-- TOC entry 560 (class 1259 OID 55757)
-- Name: user_role_status_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.user_role_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.user_role_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 573 (class 1259 OID 56391)
-- Name: user_status; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.user_status (
    id integer NOT NULL,
    status character varying(255) NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL
);


ALTER TABLE security.user_status OWNER TO timesadmin;

--
-- TOC entry 572 (class 1259 OID 56390)
-- Name: user_status_id_seq; Type: SEQUENCE; Schema: security; Owner: timesadmin
--

ALTER TABLE security.user_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME security.user_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 869 (class 1259 OID 95731)
-- Name: verification_code; Type: TABLE; Schema: security; Owner: timesadmin
--

CREATE TABLE security.verification_code (
    target_id uuid NOT NULL,
    purpose text NOT NULL,
    code character varying(6) NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE security.verification_code OWNER TO timesadmin;

--
-- TOC entry 675 (class 1259 OID 66784)
-- Name: vw_user_accessible_companies; Type: VIEW; Schema: security; Owner: timesadmin
--

CREATE VIEW security.vw_user_accessible_companies AS
 SELECT u.id AS user_id,
    u.uid AS user_uid,
    c.id AS company_id,
    c.uid AS company_uid,
    c.parent_company_id,
    c.uen,
    c.code,
    c.name AS company_name,
    c.subscription_uid,
    c.company_logo AS logo,
    c.created_on,
    c.address,
    c.created_by,
    c.updated_on,
    c.updated_by,
    c.area_id,
    a.name AS area_name,
    a.uid AS area_uid,
    i.name AS industry_name,
    i.uid AS industry_uid,
    c.sort,
    s.name AS company_status,
    c.global_code_linked,
    c.personalization_code_linked,
    c.pay_code_linked,
    ucr.role_id,
    r.name AS role_name
   FROM (((((((company.company c
     LEFT JOIN company.area a ON ((c.area_id = a.id)))
     LEFT JOIN company.industry i ON ((c.industry_id = i.id)))
     LEFT JOIN company.company_status s ON ((c.company_status_id = s.id)))
     JOIN security.user_company uc ON ((uc.company_id = c.id)))
     JOIN security."user" u ON ((u.id = uc.user_id)))
     LEFT JOIN security.user_company_role ucr ON (((ucr.company_id = c.id) AND (u.id = ucr.user_id))))
     LEFT JOIN security.role r ON ((r.id = ucr.role_id)))
  WHERE (((uc.is_implicit = true) AND (EXISTS ( SELECT 1
           FROM (security.user_role ur
             JOIN security.user_role_status urs ON ((urs.id = ur.user_role_status_id)))
          WHERE ((ur.user_id = u.id) AND (lower((urs.status)::text) = 'active'::text))))) OR (ucr.user_role_status_id = ( SELECT urs.id
           FROM security.user_role_status urs
          WHERE (lower((urs.status)::text) = lower('active'::text)))));


ALTER VIEW security.vw_user_accessible_companies OWNER TO timesadmin;

--
-- TOC entry 494 (class 1259 OID 37234)
-- Name: activity_type; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.activity_type (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    is_system_value boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.activity_type OWNER TO timesadmin;

--
-- TOC entry 521 (class 1259 OID 49157)
-- Name: cancellation_reason; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.cancellation_reason (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    description text NOT NULL,
    reason character varying(256) NOT NULL,
    is_other boolean DEFAULT false NOT NULL
);


ALTER TABLE subscription.cancellation_reason OWNER TO timesadmin;

--
-- TOC entry 520 (class 1259 OID 49156)
-- Name: cancellation_reason_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.cancellation_reason ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.cancellation_reason_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 523 (class 1259 OID 49171)
-- Name: cancellation_request; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.cancellation_request (
    id integer NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    cancellation_reason_id integer NOT NULL,
    other_reason text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.cancellation_request OWNER TO timesadmin;

--
-- TOC entry 525 (class 1259 OID 49189)
-- Name: cancellation_request_documents; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.cancellation_request_documents (
    id integer NOT NULL,
    cancellation_request_id integer NOT NULL,
    name text NOT NULL,
    url text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.cancellation_request_documents OWNER TO timesadmin;

--
-- TOC entry 524 (class 1259 OID 49188)
-- Name: cancellation_request_documents_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.cancellation_request_documents ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.cancellation_request_documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 522 (class 1259 OID 49170)
-- Name: cancellation_request_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.cancellation_request ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.cancellation_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 493 (class 1259 OID 37225)
-- Name: item; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.item (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.item OWNER TO timesadmin;

--
-- TOC entry 527 (class 1259 OID 49269)
-- Name: item_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.item ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 492 (class 1259 OID 37207)
-- Name: licensing_plan; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.licensing_plan (
    id bigint NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    allow_add_payroll_admin boolean DEFAULT false NOT NULL,
    allow_coupon_use boolean DEFAULT false NOT NULL,
    allow_priority_support boolean DEFAULT false NOT NULL,
    allow_referral_use boolean DEFAULT false NOT NULL,
    allow_upgrade_active_employee boolean DEFAULT false NOT NULL,
    default_payroll_admin integer DEFAULT 1 NOT NULL,
    effective_date timestamp without time zone,
    min_active_employee integer DEFAULT 1 NOT NULL,
    max_active_employee integer DEFAULT 999999 NOT NULL,
    status_id bigint,
    version numeric,
    document_limit integer NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    features_text text[],
    price_title_text text,
    price_sub_text text[],
    ref_licensing_plan_id bigint,
    billing_cut_off integer DEFAULT 30 NOT NULL,
    licensing_module_id bigint[]
);


ALTER TABLE subscription.licensing_plan OWNER TO timesadmin;

--
-- TOC entry 526 (class 1259 OID 49268)
-- Name: licensing_plan_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.licensing_plan ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.licensing_plan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 536 (class 1259 OID 51881)
-- Name: licensing_plan_module; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.licensing_plan_module (
    id bigint NOT NULL,
    name text NOT NULL,
    status boolean DEFAULT false NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    "order" integer DEFAULT 0 NOT NULL
);


ALTER TABLE subscription.licensing_plan_module OWNER TO timesadmin;

--
-- TOC entry 535 (class 1259 OID 51880)
-- Name: licensing_plan_module_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.licensing_plan_module ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME subscription.licensing_plan_module_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 511 (class 1259 OID 46911)
-- Name: order_detail; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.order_detail (
    id bigint NOT NULL,
    coupon_code text,
    coupon_code_discount_amount numeric(18,6),
    payment_frequency_id bigint,
    payment_frequency_unit smallint,
    payment_frequency_discount_id bigint,
    payment_frequency_discount_amount numeric(18,6),
    grand_total_amount numeric(18,6) NOT NULL,
    gst_amount numeric(18,6),
    payable_amount numeric(18,6) NOT NULL,
    total_discount_amount numeric(18,6),
    licensing_plan_id bigint,
    billing_start timestamp without time zone NOT NULL,
    billing_end timestamp without time zone NOT NULL,
    next_billing_start timestamp without time zone NOT NULL,
    next_billing_end timestamp without time zone NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.order_detail OWNER TO timesadmin;

--
-- TOC entry 510 (class 1259 OID 46910)
-- Name: order_detail_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.order_detail ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME subscription.order_detail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 495 (class 1259 OID 37244)
-- Name: payment_frequency; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.payment_frequency (
    id bigint NOT NULL,
    code text NOT NULL,
    description text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.payment_frequency OWNER TO timesadmin;

--
-- TOC entry 509 (class 1259 OID 39109)
-- Name: payment_frequency_discount; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.payment_frequency_discount (
    id bigint NOT NULL,
    payment_frequency_id bigint NOT NULL,
    unit smallint NOT NULL,
    licensing_plan_id bigint NOT NULL,
    discount numeric(18,6) NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.payment_frequency_discount OWNER TO timesadmin;

--
-- TOC entry 508 (class 1259 OID 39108)
-- Name: payment_frequency_discount_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.payment_frequency_discount ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME subscription.payment_frequency_discount_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 528 (class 1259 OID 49270)
-- Name: payment_frequency_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.payment_frequency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.payment_frequency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 496 (class 1259 OID 37254)
-- Name: payment_status; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.payment_status (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.payment_status OWNER TO timesadmin;

--
-- TOC entry 529 (class 1259 OID 49271)
-- Name: payment_status_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.payment_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.payment_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 497 (class 1259 OID 37264)
-- Name: price_item; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.price_item (
    id bigint NOT NULL,
    item_id bigint NOT NULL,
    licensing_plan_id bigint NOT NULL,
    price numeric(18,6) NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.price_item OWNER TO timesadmin;

--
-- TOC entry 530 (class 1259 OID 49273)
-- Name: price_item_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.price_item ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.price_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 498 (class 1259 OID 37274)
-- Name: subscription; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription (
    id bigint NOT NULL,
    uen text NOT NULL,
    subdomain text NOT NULL,
    subscription_status_id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_ref_id text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    licensing_plan_id bigint NOT NULL,
    customer_code text,
    is_onboarded boolean,
    active_employee_count integer DEFAULT 1 NOT NULL,
    payroll_admin_count integer DEFAULT 0 NOT NULL,
    priority_support_enabled boolean DEFAULT false NOT NULL,
    additional_storage_count integer DEFAULT 0 NOT NULL,
    ref_subscription_id integer
);


ALTER TABLE subscription.subscription OWNER TO timesadmin;

--
-- TOC entry 500 (class 1259 OID 37290)
-- Name: subscription_contract; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_contract (
    id bigint NOT NULL,
    subscription_contract_id bigint,
    subscription_uid uuid NOT NULL,
    licensing_plan_id bigint NOT NULL,
    preferred_payment text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    storage_limit integer
);


ALTER TABLE subscription.subscription_contract OWNER TO timesadmin;

--
-- TOC entry 499 (class 1259 OID 37289)
-- Name: subscription_contract_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_contract ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.subscription_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 502 (class 1259 OID 37305)
-- Name: subscription_contract_schedule; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_contract_schedule (
    id bigint NOT NULL,
    subscription_contract_id bigint NOT NULL,
    payment_frequency_id bigint NOT NULL,
    payment_frequency_unit integer NOT NULL,
    billing_start timestamp without time zone NOT NULL,
    billing_end timestamp without time zone NOT NULL,
    next_billing_start timestamp without time zone NOT NULL,
    next_billing_end timestamp without time zone NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.subscription_contract_schedule OWNER TO timesadmin;

--
-- TOC entry 501 (class 1259 OID 37304)
-- Name: subscription_contract_schedule_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_contract_schedule ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.subscription_contract_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 531 (class 1259 OID 49274)
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 515 (class 1259 OID 46962)
-- Name: subscription_invoice; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_invoice (
    id bigint NOT NULL,
    subscription_transaction_id bigint NOT NULL,
    invoice_no text,
    invoice_url text,
    receipt_url text,
    proforma_url text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.subscription_invoice OWNER TO timesadmin;

--
-- TOC entry 514 (class 1259 OID 46961)
-- Name: subscription_invoice_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_invoice ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME subscription.subscription_invoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 504 (class 1259 OID 37315)
-- Name: subscription_pricing; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_pricing (
    id bigint NOT NULL,
    subscription_contract_id integer NOT NULL,
    item_id bigint NOT NULL,
    unit_price numeric(18,6) NOT NULL,
    quantity bigint NOT NULL,
    total_price numeric(18,6) NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    payment_mode text
);


ALTER TABLE subscription.subscription_pricing OWNER TO timesadmin;

--
-- TOC entry 503 (class 1259 OID 37314)
-- Name: subscription_pricing_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_pricing ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.subscription_pricing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 505 (class 1259 OID 37326)
-- Name: subscription_status; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_status (
    id bigint NOT NULL,
    name text NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    remarks text
);


ALTER TABLE subscription.subscription_status OWNER TO timesadmin;

--
-- TOC entry 532 (class 1259 OID 49278)
-- Name: subscription_status_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME subscription.subscription_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 513 (class 1259 OID 46936)
-- Name: subscription_transaction; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_transaction (
    id bigint NOT NULL,
    uid uuid DEFAULT gen_random_uuid() NOT NULL,
    subscription_contract_id bigint NOT NULL,
    activity_type_id bigint NOT NULL,
    order_detail_id bigint,
    payment_mode text NOT NULL,
    payment_date timestamp without time zone,
    outstanding_amount numeric(18,6) NOT NULL,
    payment_status_id bigint NOT NULL,
    total_amount numeric(18,6) NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text,
    is_bank_transfer_submitted boolean DEFAULT false NOT NULL,
    transaction_code text,
    payment_client_code text
);


ALTER TABLE subscription.subscription_transaction OWNER TO timesadmin;

--
-- TOC entry 569 (class 1259 OID 55902)
-- Name: subscription_transaction_document; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_transaction_document (
    id bigint NOT NULL,
    subscription_transaction_id bigint NOT NULL,
    supporting_doc text NOT NULL,
    payment_date timestamp without time zone NOT NULL,
    amount numeric NOT NULL,
    message text,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    document_name text NOT NULL
);


ALTER TABLE subscription.subscription_transaction_document OWNER TO timesadmin;

--
-- TOC entry 568 (class 1259 OID 55901)
-- Name: subscription_transaction_document_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_transaction_document ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME subscription.subscription_transaction_document_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 512 (class 1259 OID 46935)
-- Name: subscription_transaction_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_transaction ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME subscription.subscription_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 517 (class 1259 OID 46972)
-- Name: subscription_usage; Type: TABLE; Schema: subscription; Owner: timesadmin
--

CREATE TABLE subscription.subscription_usage (
    id bigint NOT NULL,
    subscription_transaction_id bigint NOT NULL,
    item_id bigint NOT NULL,
    used_quantity bigint NOT NULL,
    used_amount numeric NOT NULL,
    created_on timestamp without time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'Admin'::text NOT NULL,
    updated_on timestamp without time zone,
    updated_by text
);


ALTER TABLE subscription.subscription_usage OWNER TO timesadmin;

--
-- TOC entry 516 (class 1259 OID 46971)
-- Name: subscription_usage_id_seq; Type: SEQUENCE; Schema: subscription; Owner: timesadmin
--

ALTER TABLE subscription.subscription_usage ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME subscription.subscription_usage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 6442 (class 2604 OID 89251)
-- Name: epm_ns_record id; Type: DEFAULT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record ALTER COLUMN id SET DEFAULT nextval('employee.epm_ns_record_id_seq'::regclass);


--
-- TOC entry 6438 (class 2604 OID 89223)
-- Name: epm_work_pass_records id; Type: DEFAULT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_work_pass_records ALTER COLUMN id SET DEFAULT nextval('employee.epm_work_pass_records_id_seq'::regclass);


--
-- TOC entry 6424 (class 2604 OID 89166)
-- Name: lk_pass_status id; Type: DEFAULT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_pass_status ALTER COLUMN id SET DEFAULT nextval('employee.lk_pass_status_id_seq'::regclass);


--
-- TOC entry 6751 (class 2604 OID 103457)
-- Name: password_reset_code id; Type: DEFAULT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.password_reset_code ALTER COLUMN id SET DEFAULT nextval('security.password_reset_code_id_seq'::regclass);


--
-- TOC entry 7163 (class 2606 OID 64896)
-- Name: absent_code absent_code_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.absent_code
    ADD CONSTRAINT absent_code_pkey PRIMARY KEY (id);


--
-- TOC entry 7067 (class 2606 OID 60682)
-- Name: allowance_deduction_back_pay_allowance allowance_deduction_back_pay_allowance_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_back_pay_allowance
    ADD CONSTRAINT allowance_deduction_back_pay_allowance_code_key UNIQUE (code);


--
-- TOC entry 7069 (class 2606 OID 60684)
-- Name: allowance_deduction_back_pay_allowance allowance_deduction_back_pay_allowance_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_back_pay_allowance
    ADD CONSTRAINT allowance_deduction_back_pay_allowance_name_key UNIQUE (name);


--
-- TOC entry 7071 (class 2606 OID 60680)
-- Name: allowance_deduction_back_pay_allowance allowance_deduction_back_pay_allowance_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_back_pay_allowance
    ADD CONSTRAINT allowance_deduction_back_pay_allowance_pkey PRIMARY KEY (id);


--
-- TOC entry 7085 (class 2606 OID 60724)
-- Name: allowance_deduction_benefit_in_kind allowance_deduction_benefit_in_kind_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_benefit_in_kind
    ADD CONSTRAINT allowance_deduction_benefit_in_kind_code_key UNIQUE (code);


--
-- TOC entry 7087 (class 2606 OID 60726)
-- Name: allowance_deduction_benefit_in_kind allowance_deduction_benefit_in_kind_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_benefit_in_kind
    ADD CONSTRAINT allowance_deduction_benefit_in_kind_name_key UNIQUE (name);


--
-- TOC entry 7089 (class 2606 OID 60722)
-- Name: allowance_deduction_benefit_in_kind allowance_deduction_benefit_in_kind_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_benefit_in_kind
    ADD CONSTRAINT allowance_deduction_benefit_in_kind_pkey PRIMARY KEY (id);


--
-- TOC entry 7055 (class 2606 OID 60654)
-- Name: allowance_deduction_bonus_type allowance_deduction_bonus_type_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_bonus_type
    ADD CONSTRAINT allowance_deduction_bonus_type_code_key UNIQUE (code);


--
-- TOC entry 7057 (class 2606 OID 60656)
-- Name: allowance_deduction_bonus_type allowance_deduction_bonus_type_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_bonus_type
    ADD CONSTRAINT allowance_deduction_bonus_type_name_key UNIQUE (name);


--
-- TOC entry 7059 (class 2606 OID 60652)
-- Name: allowance_deduction_bonus_type allowance_deduction_bonus_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_bonus_type
    ADD CONSTRAINT allowance_deduction_bonus_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7041 (class 2606 OID 60626)
-- Name: allowance_deduction_cpf allowance_deduction_cpf_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_cpf
    ADD CONSTRAINT allowance_deduction_cpf_code_key UNIQUE (code);


--
-- TOC entry 7043 (class 2606 OID 60628)
-- Name: allowance_deduction_cpf allowance_deduction_cpf_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_cpf
    ADD CONSTRAINT allowance_deduction_cpf_name_key UNIQUE (name);


--
-- TOC entry 7045 (class 2606 OID 60624)
-- Name: allowance_deduction_cpf allowance_deduction_cpf_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_cpf
    ADD CONSTRAINT allowance_deduction_cpf_pkey PRIMARY KEY (id);


--
-- TOC entry 7047 (class 2606 OID 63618)
-- Name: allowance_deduction_cpf allowance_deduction_cpf_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_cpf
    ADD CONSTRAINT allowance_deduction_cpf_uid_key UNIQUE (uid);


--
-- TOC entry 7061 (class 2606 OID 60668)
-- Name: allowance_deduction_gross_wage allowance_deduction_gross_wage_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_gross_wage
    ADD CONSTRAINT allowance_deduction_gross_wage_code_key UNIQUE (code);


--
-- TOC entry 7063 (class 2606 OID 60670)
-- Name: allowance_deduction_gross_wage allowance_deduction_gross_wage_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_gross_wage
    ADD CONSTRAINT allowance_deduction_gross_wage_name_key UNIQUE (name);


--
-- TOC entry 7065 (class 2606 OID 60666)
-- Name: allowance_deduction_gross_wage allowance_deduction_gross_wage_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_gross_wage
    ADD CONSTRAINT allowance_deduction_gross_wage_pkey PRIMARY KEY (id);


--
-- TOC entry 7079 (class 2606 OID 60710)
-- Name: allowance_deduction_grp_formula allowance_deduction_grp_formula_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_grp_formula
    ADD CONSTRAINT allowance_deduction_grp_formula_code_key UNIQUE (code);


--
-- TOC entry 7081 (class 2606 OID 60712)
-- Name: allowance_deduction_grp_formula allowance_deduction_grp_formula_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_grp_formula
    ADD CONSTRAINT allowance_deduction_grp_formula_name_key UNIQUE (name);


--
-- TOC entry 7083 (class 2606 OID 60708)
-- Name: allowance_deduction_grp_formula allowance_deduction_grp_formula_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_grp_formula
    ADD CONSTRAINT allowance_deduction_grp_formula_pkey PRIMARY KEY (id);


--
-- TOC entry 7091 (class 2606 OID 60755)
-- Name: allowance_deduction allowance_deduction_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_pkey PRIMARY KEY (id);


--
-- TOC entry 7033 (class 2606 OID 60612)
-- Name: allowance_deduction_tax allowance_deduction_tax_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_tax
    ADD CONSTRAINT allowance_deduction_tax_code_key UNIQUE (code);


--
-- TOC entry 7035 (class 2606 OID 60614)
-- Name: allowance_deduction_tax allowance_deduction_tax_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_tax
    ADD CONSTRAINT allowance_deduction_tax_name_key UNIQUE (name);


--
-- TOC entry 7037 (class 2606 OID 60610)
-- Name: allowance_deduction_tax allowance_deduction_tax_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_tax
    ADD CONSTRAINT allowance_deduction_tax_pkey PRIMARY KEY (id);


--
-- TOC entry 7039 (class 2606 OID 63746)
-- Name: allowance_deduction_tax allowance_deduction_tax_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_tax
    ADD CONSTRAINT allowance_deduction_tax_uid_key UNIQUE (uid);


--
-- TOC entry 7049 (class 2606 OID 60640)
-- Name: allowance_deduction_type allowance_deduction_type_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_type
    ADD CONSTRAINT allowance_deduction_type_code_key UNIQUE (code);


--
-- TOC entry 7051 (class 2606 OID 60642)
-- Name: allowance_deduction_type allowance_deduction_type_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_type
    ADD CONSTRAINT allowance_deduction_type_name_key UNIQUE (name);


--
-- TOC entry 7053 (class 2606 OID 60638)
-- Name: allowance_deduction_type allowance_deduction_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_type
    ADD CONSTRAINT allowance_deduction_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7073 (class 2606 OID 60696)
-- Name: allowance_deduction_unit allowance_deduction_unit_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_unit
    ADD CONSTRAINT allowance_deduction_unit_code_key UNIQUE (code);


--
-- TOC entry 7075 (class 2606 OID 60698)
-- Name: allowance_deduction_unit allowance_deduction_unit_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_unit
    ADD CONSTRAINT allowance_deduction_unit_name_key UNIQUE (name);


--
-- TOC entry 7077 (class 2606 OID 60694)
-- Name: allowance_deduction_unit allowance_deduction_unit_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction_unit
    ADD CONSTRAINT allowance_deduction_unit_pkey PRIMARY KEY (id);


--
-- TOC entry 6835 (class 2606 OID 35532)
-- Name: area area_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.area
    ADD CONSTRAINT area_pkey PRIMARY KEY (id);


--
-- TOC entry 7459 (class 2606 OID 95664)
-- Name: company_asset asset_id_company_unq; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_asset
    ADD CONSTRAINT asset_id_company_unq UNIQUE (company_id, asset_id);


--
-- TOC entry 7471 (class 2606 OID 97814)
-- Name: asset_management_log asset_management_log_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.asset_management_log
    ADD CONSTRAINT asset_management_log_pkey PRIMARY KEY (id);


--
-- TOC entry 6839 (class 2606 OID 35561)
-- Name: bank bank_bank_code_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank
    ADD CONSTRAINT bank_bank_code_key UNIQUE (bank_code);


--
-- TOC entry 6843 (class 2606 OID 38205)
-- Name: bank_branch bank_branch_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank_branch
    ADD CONSTRAINT bank_branch_pkey PRIMARY KEY (id);


--
-- TOC entry 6837 (class 2606 OID 35550)
-- Name: bank_category bank_category_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank_category
    ADD CONSTRAINT bank_category_pkey PRIMARY KEY (id);


--
-- TOC entry 6841 (class 2606 OID 35559)
-- Name: bank bank_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank
    ADD CONSTRAINT bank_pkey PRIMARY KEY (id);


--
-- TOC entry 7398 (class 2606 OID 93539)
-- Name: bank_type bank_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank_type
    ADD CONSTRAINT bank_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7255 (class 2606 OID 75625)
-- Name: claim_financial_period claim_financial_period_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.claim_financial_period
    ADD CONSTRAINT claim_financial_period_pkey PRIMARY KEY (id);


--
-- TOC entry 7257 (class 2606 OID 75627)
-- Name: claim_financial_period claim_financial_period_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.claim_financial_period
    ADD CONSTRAINT claim_financial_period_uid_key UNIQUE (uid);


--
-- TOC entry 7093 (class 2606 OID 60957)
-- Name: code_setup_category code_setup_category_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup_category
    ADD CONSTRAINT code_setup_category_pkey PRIMARY KEY (id);


--
-- TOC entry 7022 (class 2606 OID 56874)
-- Name: code_setup_type code_setup_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup_type
    ADD CONSTRAINT code_setup_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7161 (class 2606 OID 64879)
-- Name: company_absent company_absent_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_absent
    ADD CONSTRAINT company_absent_pkey PRIMARY KEY (id);


--
-- TOC entry 6910 (class 2606 OID 37110)
-- Name: company_address_info_kiv company_address_info_kiv_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_address_info_kiv
    ADD CONSTRAINT company_address_info_kiv_pkey PRIMARY KEY (id);


--
-- TOC entry 7461 (class 2606 OID 95662)
-- Name: company_asset company_asset_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_asset
    ADD CONSTRAINT company_asset_pkey PRIMARY KEY (id);


--
-- TOC entry 6867 (class 2606 OID 36474)
-- Name: company_bank company_bank_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_bank
    ADD CONSTRAINT company_bank_pkey PRIMARY KEY (id);


--
-- TOC entry 7012 (class 2606 OID 55885)
-- Name: company_employment_setting company_employment_setting_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_employment_setting
    ADD CONSTRAINT company_employment_setting_pkey PRIMARY KEY (id);


--
-- TOC entry 7374 (class 2606 OID 90900)
-- Name: company_levy_management company_levy_management_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_levy_management
    ADD CONSTRAINT company_levy_management_pkey PRIMARY KEY (id);


--
-- TOC entry 7183 (class 2606 OID 67429)
-- Name: company_nsp_setup company_nsp_setup_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_nsp_setup
    ADD CONSTRAINT company_nsp_setup_pkey PRIMARY KEY (id);


--
-- TOC entry 7195 (class 2606 OID 73659)
-- Name: company_ot_capping company_ot_capping_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_ot_capping
    ADD CONSTRAINT company_ot_capping_pkey PRIMARY KEY (id);


--
-- TOC entry 7151 (class 2606 OID 63698)
-- Name: company_ot_rate company_ot_rate_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_ot_rate
    ADD CONSTRAINT company_ot_rate_pkey PRIMARY KEY (id);


--
-- TOC entry 7157 (class 2606 OID 64768)
-- Name: company_public_holiday company_public_holiday_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_public_holiday
    ADD CONSTRAINT company_public_holiday_pkey PRIMARY KEY (id);


--
-- TOC entry 7167 (class 2606 OID 64974)
-- Name: company_shift_setup company_shift_setup_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_shift_setup
    ADD CONSTRAINT company_shift_setup_pkey PRIMARY KEY (id);


--
-- TOC entry 6855 (class 2606 OID 36286)
-- Name: company_status company_status_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_status
    ADD CONSTRAINT company_status_pkey PRIMARY KEY (id);


--
-- TOC entry 6849 (class 2606 OID 36245)
-- Name: country country__pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.country
    ADD CONSTRAINT country__pkey PRIMARY KEY (id);


--
-- TOC entry 6853 (class 2606 OID 36265)
-- Name: country_city country_city_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.country_city
    ADD CONSTRAINT country_city_pkey PRIMARY KEY (id);


--
-- TOC entry 6851 (class 2606 OID 36253)
-- Name: country_state country_state_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.country_state
    ADD CONSTRAINT country_state_pkey PRIMARY KEY (id);


--
-- TOC entry 6873 (class 2606 OID 36580)
-- Name: cpf_account cpf_account_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.cpf_account
    ADD CONSTRAINT cpf_account_pkey PRIMARY KEY (id);


--
-- TOC entry 7227 (class 2606 OID 73840)
-- Name: customize_rest_day_grouping customize_rest_day_grouping_employment_classification_id_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.customize_rest_day_grouping
    ADD CONSTRAINT customize_rest_day_grouping_employment_classification_id_key UNIQUE (employment_classification_id);


--
-- TOC entry 7229 (class 2606 OID 73836)
-- Name: customize_rest_day_grouping customize_rest_day_grouping_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.customize_rest_day_grouping
    ADD CONSTRAINT customize_rest_day_grouping_pkey PRIMARY KEY (id);


--
-- TOC entry 7231 (class 2606 OID 73838)
-- Name: customize_rest_day_grouping customize_rest_day_grouping_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.customize_rest_day_grouping
    ADD CONSTRAINT customize_rest_day_grouping_uid_key UNIQUE (uid);


--
-- TOC entry 7500 (class 2606 OID 101439)
-- Name: query_builder_rules data_security_rules_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.query_builder_rules
    ADD CONSTRAINT data_security_rules_pkey PRIMARY KEY (id);


--
-- TOC entry 7524 (class 2606 OID 104423)
-- Name: default_queries default_queries_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.default_queries
    ADD CONSTRAINT default_queries_pkey PRIMARY KEY (id);


--
-- TOC entry 6875 (class 2606 OID 36605)
-- Name: document_category document_category_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.document_category
    ADD CONSTRAINT document_category_pkey PRIMARY KEY (id);


--
-- TOC entry 7564 (class 2606 OID 112749)
-- Name: document_favourite document_favourite_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.document_favourite
    ADD CONSTRAINT document_favourite_pkey PRIMARY KEY (user_id, document_id);


--
-- TOC entry 6877 (class 2606 OID 112743)
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- TOC entry 7155 (class 2606 OID 63757)
-- Name: encashment_method encashment_method_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.encashment_method
    ADD CONSTRAINT encashment_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7269 (class 2606 OID 75673)
-- Name: formula_setup_settings formula_setup_settings_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.formula_setup_settings
    ADD CONSTRAINT formula_setup_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 6845 (class 2606 OID 36220)
-- Name: industry_group industry_group_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.industry_group
    ADD CONSTRAINT industry_group_pkey PRIMARY KEY (id);


--
-- TOC entry 6847 (class 2606 OID 36229)
-- Name: industry industry_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.industry
    ADD CONSTRAINT industry_pkey PRIMARY KEY (id);


--
-- TOC entry 7251 (class 2606 OID 75604)
-- Name: leave_financial_period leave_financial_period_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.leave_financial_period
    ADD CONSTRAINT leave_financial_period_pkey PRIMARY KEY (id);


--
-- TOC entry 7376 (class 2606 OID 90964)
-- Name: levy_management_pay_period levy_management_pay_period_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.levy_management_pay_period
    ADD CONSTRAINT levy_management_pay_period_pkey PRIMARY KEY (id);


--
-- TOC entry 7299 (class 2606 OID 78297)
-- Name: lk_age_type lk_age_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_age_type
    ADD CONSTRAINT lk_age_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7467 (class 2606 OID 97439)
-- Name: lk_asset_management_log_action lk_asset_management_log_action_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_asset_management_log_action
    ADD CONSTRAINT lk_asset_management_log_action_pkey PRIMARY KEY (id);


--
-- TOC entry 7457 (class 2606 OID 95649)
-- Name: lk_asset_status lk_asset_status_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_asset_status
    ADD CONSTRAINT lk_asset_status_pkey PRIMARY KEY (id);


--
-- TOC entry 7165 (class 2606 OID 64961)
-- Name: lk_average_shift_month lk_average_shift_month_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_average_shift_month
    ADD CONSTRAINT lk_average_shift_month_pkey PRIMARY KEY (id);


--
-- TOC entry 7289 (class 2606 OID 78110)
-- Name: lk_community_fund_category lk_community_fund_category_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_community_fund_category
    ADD CONSTRAINT lk_community_fund_category_name_key UNIQUE (name);


--
-- TOC entry 7291 (class 2606 OID 78108)
-- Name: lk_community_fund_category lk_community_fund_category_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_community_fund_category
    ADD CONSTRAINT lk_community_fund_category_pkey PRIMARY KEY (id);


--
-- TOC entry 7293 (class 2606 OID 78112)
-- Name: lk_community_fund_category lk_community_fund_category_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_community_fund_category
    ADD CONSTRAINT lk_community_fund_category_uid_key UNIQUE (uid);


--
-- TOC entry 7287 (class 2606 OID 78097)
-- Name: lk_donation_category lk_donation_category_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_donation_category
    ADD CONSTRAINT lk_donation_category_pkey PRIMARY KEY (id);


--
-- TOC entry 7169 (class 2606 OID 65035)
-- Name: lk_duration_unit lk_duration_unit_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_duration_unit
    ADD CONSTRAINT lk_duration_unit_pkey PRIMARY KEY (id);


--
-- TOC entry 7265 (class 2606 OID 75658)
-- Name: lk_formula_setup_method lk_formula_setup_method__pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_formula_setup_method
    ADD CONSTRAINT lk_formula_setup_method__pkey PRIMARY KEY (id);


--
-- TOC entry 7267 (class 2606 OID 75660)
-- Name: lk_formula_setup_method lk_formula_setup_method_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_formula_setup_method
    ADD CONSTRAINT lk_formula_setup_method_uid_key UNIQUE (uid);


--
-- TOC entry 7372 (class 2606 OID 90882)
-- Name: lk_levy_method lk_levy_method_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_levy_method
    ADD CONSTRAINT lk_levy_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7181 (class 2606 OID 67413)
-- Name: lk_nsp_formula lk_nsp_formula_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_nsp_formula
    ADD CONSTRAINT lk_nsp_formula_pkey PRIMARY KEY (id);


--
-- TOC entry 7193 (class 2606 OID 73628)
-- Name: lk_ot_ceiling_method lk_ot_ceiling_method_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_ot_ceiling_method
    ADD CONSTRAINT lk_ot_ceiling_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7145 (class 2606 OID 63652)
-- Name: lk_ot_ceiling_type lk_ot_ceiling_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_ot_ceiling_type
    ADD CONSTRAINT lk_ot_ceiling_pkey PRIMARY KEY (id);


--
-- TOC entry 7147 (class 2606 OID 63663)
-- Name: lk_ot_rate_formula lk_ot_rate_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_ot_rate_formula
    ADD CONSTRAINT lk_ot_rate_pkey PRIMARY KEY (id);


--
-- TOC entry 7149 (class 2606 OID 63674)
-- Name: lk_ot_rate_setting lk_ot_rate_setting_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_ot_rate_setting
    ADD CONSTRAINT lk_ot_rate_setting_pkey PRIMARY KEY (id);


--
-- TOC entry 7197 (class 2606 OID 73687)
-- Name: lk_prorate_formula lk_prorate_formula_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_prorate_formula
    ADD CONSTRAINT lk_prorate_formula_pkey PRIMARY KEY (id);


--
-- TOC entry 7199 (class 2606 OID 73689)
-- Name: lk_prorate_formula lk_prorate_formula_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_prorate_formula
    ADD CONSTRAINT lk_prorate_formula_uid_key UNIQUE (uid);


--
-- TOC entry 7261 (class 2606 OID 75645)
-- Name: lk_prorate_salary_formula lk_prorate_salary_formula_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_prorate_salary_formula
    ADD CONSTRAINT lk_prorate_salary_formula_pkey PRIMARY KEY (id);


--
-- TOC entry 7263 (class 2606 OID 75647)
-- Name: lk_prorate_salary_formula lk_prorate_salary_formula_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_prorate_salary_formula
    ADD CONSTRAINT lk_prorate_salary_formula_uid_key UNIQUE (uid);


--
-- TOC entry 7215 (class 2606 OID 73788)
-- Name: lk_rd_ceiling_method lk_rd_ceiling_method_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rd_ceiling_method
    ADD CONSTRAINT lk_rd_ceiling_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7217 (class 2606 OID 73790)
-- Name: lk_rd_ceiling_method lk_rd_ceiling_method_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rd_ceiling_method
    ADD CONSTRAINT lk_rd_ceiling_method_uid_key UNIQUE (uid);


--
-- TOC entry 7219 (class 2606 OID 73801)
-- Name: lk_rd_ceiling lk_rd_ceiling_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rd_ceiling
    ADD CONSTRAINT lk_rd_ceiling_pkey PRIMARY KEY (id);


--
-- TOC entry 7221 (class 2606 OID 73803)
-- Name: lk_rd_ceiling lk_rd_ceiling_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rd_ceiling
    ADD CONSTRAINT lk_rd_ceiling_uid_key UNIQUE (uid);


--
-- TOC entry 7107 (class 2606 OID 62187)
-- Name: lk_rounding_method lk_rounding_method_name_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rounding_method
    ADD CONSTRAINT lk_rounding_method_name_key UNIQUE (name);


--
-- TOC entry 7109 (class 2606 OID 62185)
-- Name: lk_rounding_method lk_rounding_method_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rounding_method
    ADD CONSTRAINT lk_rounding_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7111 (class 2606 OID 62189)
-- Name: lk_rounding_method lk_rounding_method_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rounding_method
    ADD CONSTRAINT lk_rounding_method_uid_key UNIQUE (uid);


--
-- TOC entry 7307 (class 2606 OID 80495)
-- Name: lk_union_category lk_union_category_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_union_category
    ADD CONSTRAINT lk_union_category_pkey PRIMARY KEY (id);


--
-- TOC entry 7534 (class 2606 OID 105291)
-- Name: module_lock_configuration_module module_lock_configuration_module_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.module_lock_configuration_module
    ADD CONSTRAINT module_lock_configuration_module_pkey PRIMARY KEY (id);


--
-- TOC entry 7530 (class 2606 OID 105262)
-- Name: module_lock_configuration module_lock_configuration_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.module_lock_configuration
    ADD CONSTRAINT module_lock_configuration_pkey PRIMARY KEY (id);


--
-- TOC entry 7113 (class 2606 OID 62203)
-- Name: npl_configuration npl_configuration_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.npl_configuration
    ADD CONSTRAINT npl_configuration_pkey PRIMARY KEY (id);


--
-- TOC entry 7115 (class 2606 OID 62232)
-- Name: npl_rate npl_rate_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.npl_rate
    ADD CONSTRAINT npl_rate_pkey PRIMARY KEY (id);


--
-- TOC entry 7095 (class 2606 OID 60968)
-- Name: occupation_category occupation_category_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.occupation_category
    ADD CONSTRAINT occupation_category_pkey PRIMARY KEY (id);


--
-- TOC entry 6894 (class 2606 OID 36805)
-- Name: organization_types organization_types_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.organization_types
    ADD CONSTRAINT organization_types_pkey PRIMARY KEY (id);


--
-- TOC entry 7233 (class 2606 OID 73934)
-- Name: ot_capping_code ot_capping_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_capping_code
    ADD CONSTRAINT ot_capping_pkey PRIMARY KEY (id);


--
-- TOC entry 7153 (class 2606 OID 63715)
-- Name: ot_rate_code ot_rate_code_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_rate_code
    ADD CONSTRAINT ot_rate_code_pkey PRIMARY KEY (id);


--
-- TOC entry 7279 (class 2606 OID 78058)
-- Name: pay_group_calendar pay_group_calendar_pay_group_id_period_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_calendar
    ADD CONSTRAINT pay_group_calendar_pay_group_id_period_key UNIQUE (pay_group_id, period);


--
-- TOC entry 7281 (class 2606 OID 78056)
-- Name: pay_group_calendar pay_group_calendar_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_calendar
    ADD CONSTRAINT pay_group_calendar_pkey PRIMARY KEY (id);


--
-- TOC entry 7271 (class 2606 OID 79490)
-- Name: pay_group pay_group_company_id_pay_group_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group
    ADD CONSTRAINT pay_group_company_id_pay_group_key UNIQUE (year, company_id, pay_group);


--
-- TOC entry 7275 (class 2606 OID 78037)
-- Name: pay_group_global_weekly_settings pay_group_global_weekly_settings_pay_group_id_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_global_weekly_settings
    ADD CONSTRAINT pay_group_global_weekly_settings_pay_group_id_key UNIQUE (pay_group_id);


--
-- TOC entry 7277 (class 2606 OID 78035)
-- Name: pay_group_global_weekly_settings pay_group_global_weekly_settings_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_global_weekly_settings
    ADD CONSTRAINT pay_group_global_weekly_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 7273 (class 2606 OID 77988)
-- Name: pay_group pay_group_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group
    ADD CONSTRAINT pay_group_pkey PRIMARY KEY (id);


--
-- TOC entry 7283 (class 2606 OID 78079)
-- Name: pay_group_weekly pay_group_weekly_pay_group_id_period_week_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_weekly
    ADD CONSTRAINT pay_group_weekly_pay_group_id_period_week_key UNIQUE (pay_group_id, period, week);


--
-- TOC entry 7285 (class 2606 OID 78077)
-- Name: pay_group_weekly pay_group_weekly_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_weekly
    ADD CONSTRAINT pay_group_weekly_pkey PRIMARY KEY (id);


--
-- TOC entry 6896 (class 2606 OID 36814)
-- Name: payer_types payer_types_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payer_types
    ADD CONSTRAINT payer_types_pkey PRIMARY KEY (id);


--
-- TOC entry 6898 (class 2606 OID 36822)
-- Name: payment_method payment_method_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payment_method
    ADD CONSTRAINT payment_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7400 (class 2606 OID 93548)
-- Name: payment_mode payment_mode_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payment_mode
    ADD CONSTRAINT payment_mode_pkey PRIMARY KEY (id);


--
-- TOC entry 6863 (class 2606 OID 36445)
-- Name: payment_profile payment_profile_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payment_profile
    ADD CONSTRAINT payment_profile_pkey PRIMARY KEY (id);


--
-- TOC entry 6865 (class 2606 OID 36466)
-- Name: payment_type payment_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payment_type
    ADD CONSTRAINT payment_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7247 (class 2606 OID 75584)
-- Name: payroll_financial_period payroll_financial_period_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payroll_financial_period
    ADD CONSTRAINT payroll_financial_period_pkey PRIMARY KEY (id);


--
-- TOC entry 7010 (class 2606 OID 55868)
-- Name: period_type period_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.period_type
    ADD CONSTRAINT period_type_pkey PRIMARY KEY (id);


--
-- TOC entry 6859 (class 2606 OID 36377)
-- Name: company pk_company; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company
    ADD CONSTRAINT pk_company PRIMARY KEY (id);


--
-- TOC entry 6869 (class 2606 OID 36519)
-- Name: company_contact_info pk_company_contact_info; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_contact_info
    ADD CONSTRAINT pk_company_contact_info PRIMARY KEY (id);


--
-- TOC entry 7496 (class 2606 OID 101476)
-- Name: lk_status pk_lk_status; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_status
    ADD CONSTRAINT pk_lk_status PRIMARY KEY (id);


--
-- TOC entry 7143 (class 2606 OID 63592)
-- Name: sg_oed_map_code pkey_code_oed_mapping; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_oed_map_code
    ADD CONSTRAINT pkey_code_oed_mapping PRIMARY KEY (id);


--
-- TOC entry 7025 (class 2606 OID 56886)
-- Name: code_setup pkey_code_setup; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT pkey_code_setup PRIMARY KEY (id);


--
-- TOC entry 7008 (class 2606 OID 55852)
-- Name: company_organization_structure pkey_company_org; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_organization_structure
    ADD CONSTRAINT pkey_company_org PRIMARY KEY (id);


--
-- TOC entry 7137 (class 2606 OID 62687)
-- Name: company_rest_day pkey_company_rest_day; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_rest_day
    ADD CONSTRAINT pkey_company_rest_day PRIMARY KEY (id);


--
-- TOC entry 7101 (class 2606 OID 62133)
-- Name: lk_daily_rate pkey_daily_rate; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_daily_rate
    ADD CONSTRAINT pkey_daily_rate PRIMARY KEY (id);


--
-- TOC entry 6879 (class 2606 OID 36641)
-- Name: id_provident_fund pkey_id_pf; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_provident_fund
    ADD CONSTRAINT pkey_id_pf PRIMARY KEY (id);


--
-- TOC entry 6885 (class 2606 OID 36694)
-- Name: id_tax_requirement pkey_id_tax_requirement; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_tax_requirement
    ADD CONSTRAINT pkey_id_tax_requirement PRIMARY KEY (id);


--
-- TOC entry 6871 (class 2606 OID 36537)
-- Name: company_layout pkey_layout_company; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_layout
    ADD CONSTRAINT pkey_layout_company PRIMARY KEY (id);


--
-- TOC entry 6892 (class 2606 OID 36786)
-- Name: my_provident_fund pkey_my_pf; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.my_provident_fund
    ADD CONSTRAINT pkey_my_pf PRIMARY KEY (id);


--
-- TOC entry 6934 (class 2606 OID 38288)
-- Name: my_tax_requirement pkey_my_tax; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.my_tax_requirement
    ADD CONSTRAINT pkey_my_tax PRIMARY KEY (id);


--
-- TOC entry 7131 (class 2606 OID 62405)
-- Name: company_rate_formula pkey_rate_formula; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_rate_formula
    ADD CONSTRAINT pkey_rate_formula PRIMARY KEY (id);


--
-- TOC entry 7141 (class 2606 OID 62931)
-- Name: rest_day_code pkey_rest_day_code; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_code
    ADD CONSTRAINT pkey_rest_day_code PRIMARY KEY (id);


--
-- TOC entry 7103 (class 2606 OID 62163)
-- Name: lk_rest_day_rate pkey_rest_day_rate; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rest_day_rate
    ADD CONSTRAINT pkey_rest_day_rate PRIMARY KEY (id);


--
-- TOC entry 7105 (class 2606 OID 62174)
-- Name: lk_rest_day_status pkey_rest_day_status; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.lk_rest_day_status
    ADD CONSTRAINT pkey_rest_day_status PRIMARY KEY (id);


--
-- TOC entry 6881 (class 2606 OID 36656)
-- Name: id_tax_refund_calculation pkey_tax_refund; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_tax_refund_calculation
    ADD CONSTRAINT pkey_tax_refund PRIMARY KEY (id);


--
-- TOC entry 6883 (class 2606 OID 36680)
-- Name: id_wage_type pkey_wage; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_wage_type
    ADD CONSTRAINT pkey_wage PRIMARY KEY (id);


--
-- TOC entry 7201 (class 2606 OID 73704)
-- Name: prorate_allowance_configuration prorate_allowance_configuration_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_configuration
    ADD CONSTRAINT prorate_allowance_configuration_pkey PRIMARY KEY (id);


--
-- TOC entry 7205 (class 2606 OID 73727)
-- Name: prorate_allowance_deduction_assignment prorate_allowance_deduction_assignment_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_assignment
    ADD CONSTRAINT prorate_allowance_deduction_assignment_pkey PRIMARY KEY (id);


--
-- TOC entry 7207 (class 2606 OID 73729)
-- Name: prorate_allowance_deduction_assignment prorate_allowance_deduction_assignment_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_assignment
    ADD CONSTRAINT prorate_allowance_deduction_assignment_uid_key UNIQUE (uid);


--
-- TOC entry 7213 (class 2606 OID 73767)
-- Name: prorate_allowance_deduction_leave_assignment prorate_allowance_deduction_leave_assignment_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_leave_assignment
    ADD CONSTRAINT prorate_allowance_deduction_leave_assignment_pkey PRIMARY KEY (id);


--
-- TOC entry 7159 (class 2606 OID 64799)
-- Name: public_holiday_code public_holiday_code_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday_code
    ADD CONSTRAINT public_holiday_code_pkey PRIMARY KEY (id);


--
-- TOC entry 7191 (class 2606 OID 72388)
-- Name: public_holiday public_holiday_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday
    ADD CONSTRAINT public_holiday_pkey PRIMARY KEY (id);


--
-- TOC entry 7189 (class 2606 OID 72374)
-- Name: public_holiday_type public_holioday_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday_type
    ADD CONSTRAINT public_holioday_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7504 (class 2606 OID 101489)
-- Name: query_builder_rule_users query_builder_rule_users_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.query_builder_rule_users
    ADD CONSTRAINT query_builder_rule_users_pkey PRIMARY KEY (id);


--
-- TOC entry 7020 (class 2606 OID 56864)
-- Name: relation_type relation_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.relation_type
    ADD CONSTRAINT relation_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7223 (class 2606 OID 80577)
-- Name: rest_day_capping_settings rest_day_capping_settings_company_id_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_capping_settings
    ADD CONSTRAINT rest_day_capping_settings_company_id_key UNIQUE (company_id);


--
-- TOC entry 7225 (class 2606 OID 73815)
-- Name: rest_day_capping_settings rest_day_capping_settings_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_capping_settings
    ADD CONSTRAINT rest_day_capping_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 7481 (class 2606 OID 100440)
-- Name: salary_scale_setup salary_scale_setup_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.salary_scale_setup
    ADD CONSTRAINT salary_scale_setup_pkey PRIMARY KEY (salary_scale_id);


--
-- TOC entry 7483 (class 2606 OID 100456)
-- Name: salary_scale_step salary_scale_step_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.salary_scale_step
    ADD CONSTRAINT salary_scale_step_pkey PRIMARY KEY (id);


--
-- TOC entry 7295 (class 2606 OID 78136)
-- Name: sg_community_fund_setup sg_community_fund_setup_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT sg_community_fund_setup_pkey PRIMARY KEY (id);


--
-- TOC entry 7384 (class 2606 OID 92054)
-- Name: sg_cpf_profile sg_cpf_profile_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_cpf_profile
    ADD CONSTRAINT sg_cpf_profile_pkey PRIMARY KEY (id);


--
-- TOC entry 7301 (class 2606 OID 78309)
-- Name: sg_cpf_setup sg_cpf_setup_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_cpf_setup
    ADD CONSTRAINT sg_cpf_setup_pkey PRIMARY KEY (id);


--
-- TOC entry 7378 (class 2606 OID 91971)
-- Name: sg_donation_setup_link sg_donation_link_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup_link
    ADD CONSTRAINT sg_donation_link_pkey PRIMARY KEY (id);


--
-- TOC entry 7297 (class 2606 OID 78214)
-- Name: sg_donation_setup sg_donation_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT sg_donation_pkey PRIMARY KEY (id);


--
-- TOC entry 7097 (class 2606 OID 60979)
-- Name: sg_highest_education_attained sg_highest_education_attained_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_highest_education_attained
    ADD CONSTRAINT sg_highest_education_attained_pkey PRIMARY KEY (id);


--
-- TOC entry 7099 (class 2606 OID 60990)
-- Name: sg_occupation_group sg_occupation_group_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_occupation_group
    ADD CONSTRAINT sg_occupation_group_pkey PRIMARY KEY (id);


--
-- TOC entry 6906 (class 2606 OID 36829)
-- Name: sg_provident_fund sg_provident_fund_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_provident_fund
    ADD CONSTRAINT sg_provident_fund_pkey PRIMARY KEY (id);


--
-- TOC entry 6908 (class 2606 OID 48871)
-- Name: sg_tax_requirement sg_tax_requirement_detail_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_tax_requirement
    ADD CONSTRAINT sg_tax_requirement_detail_pkey PRIMARY KEY (id);


--
-- TOC entry 7309 (class 2606 OID 80518)
-- Name: sg_union_setup sg_union_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT sg_union_pkey PRIMARY KEY (id);


--
-- TOC entry 7171 (class 2606 OID 65055)
-- Name: shift_setup_code shift_setup_code_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.shift_setup_code
    ADD CONSTRAINT shift_setup_code_pkey PRIMARY KEY (id);


--
-- TOC entry 6861 (class 2606 OID 84011)
-- Name: company uid_uq; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company
    ADD CONSTRAINT uid_uq UNIQUE (uid);


--
-- TOC entry 7239 (class 2606 OID 75522)
-- Name: union_bonus_type union_bonus_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_bonus_type
    ADD CONSTRAINT union_bonus_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7241 (class 2606 OID 75524)
-- Name: union_bonus_type union_bonus_type_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_bonus_type
    ADD CONSTRAINT union_bonus_type_uid_key UNIQUE (uid);


--
-- TOC entry 7245 (class 2606 OID 75561)
-- Name: union_bonus union_bonus_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_bonus
    ADD CONSTRAINT union_bonus_uid_key UNIQUE (uid);


--
-- TOC entry 7235 (class 2606 OID 75504)
-- Name: union_type union_type_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_type
    ADD CONSTRAINT union_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7237 (class 2606 OID 75506)
-- Name: union_type union_type_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_type
    ADD CONSTRAINT union_type_uid_key UNIQUE (uid);


--
-- TOC entry 7243 (class 2606 OID 75540)
-- Name: union union_uid_key; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company."union"
    ADD CONSTRAINT union_uid_key UNIQUE (uid);


--
-- TOC entry 7386 (class 2606 OID 92108)
-- Name: sg_union_setup_link uniq_union_link_company_id; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup_link
    ADD CONSTRAINT uniq_union_link_company_id UNIQUE (company_id);


--
-- TOC entry 7259 (class 2606 OID 75634)
-- Name: claim_financial_period uq_claim_financial_period_company_year; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.claim_financial_period
    ADD CONSTRAINT uq_claim_financial_period_company_year UNIQUE (company_id, year);


--
-- TOC entry 7027 (class 2606 OID 110742)
-- Name: code_setup uq_code_setup_id_company; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT uq_code_setup_id_company UNIQUE (id, company_id);


--
-- TOC entry 7029 (class 2606 OID 80007)
-- Name: code_setup uq_code_setup_id_type; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT uq_code_setup_id_type UNIQUE (id, code_setup_type_id);


--
-- TOC entry 7526 (class 2606 OID 104427)
-- Name: default_queries uq_default_queries_module_name; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.default_queries
    ADD CONSTRAINT uq_default_queries_module_name UNIQUE (module_id, name);


--
-- TOC entry 7528 (class 2606 OID 104425)
-- Name: default_queries uq_default_queries_uuid; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.default_queries
    ADD CONSTRAINT uq_default_queries_uuid UNIQUE (uuid);


--
-- TOC entry 7253 (class 2606 OID 75611)
-- Name: leave_financial_period uq_leave_financial_period_company_year; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.leave_financial_period
    ADD CONSTRAINT uq_leave_financial_period_company_year UNIQUE (company_id, year);


--
-- TOC entry 7532 (class 2606 OID 105264)
-- Name: module_lock_configuration uq_module_lock_configuration_company; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.module_lock_configuration
    ADD CONSTRAINT uq_module_lock_configuration_company UNIQUE (company_id);


--
-- TOC entry 7536 (class 2606 OID 105295)
-- Name: module_lock_configuration_module uq_module_lock_configuration_module; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.module_lock_configuration_module
    ADD CONSTRAINT uq_module_lock_configuration_module UNIQUE (module_lock_configuration_id, module_uid);


--
-- TOC entry 7538 (class 2606 OID 105293)
-- Name: module_lock_configuration_module uq_module_lock_configuration_module_uid; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.module_lock_configuration_module
    ADD CONSTRAINT uq_module_lock_configuration_module_uid UNIQUE (uid);


--
-- TOC entry 7249 (class 2606 OID 75591)
-- Name: payroll_financial_period uq_payroll_financial_period_company_year; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payroll_financial_period
    ADD CONSTRAINT uq_payroll_financial_period_company_year UNIQUE (company_id, year);


--
-- TOC entry 7203 (class 2606 OID 73716)
-- Name: prorate_allowance_configuration uq_prorate_allowance_company; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_configuration
    ADD CONSTRAINT uq_prorate_allowance_company UNIQUE (company_id);


--
-- TOC entry 7506 (class 2606 OID 101491)
-- Name: query_builder_rule_users uq_rule_user; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.query_builder_rule_users
    ADD CONSTRAINT uq_rule_user UNIQUE (rule_id, user_id);


--
-- TOC entry 7187 (class 2606 OID 70272)
-- Name: work_code work_code_pkey; Type: CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.work_code
    ADD CONSTRAINT work_code_pkey PRIMARY KEY (id);


--
-- TOC entry 7370 (class 2606 OID 89757)
-- Name: address_usage_type address_usage_type_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.address_usage_type
    ADD CONSTRAINT address_usage_type_pkey PRIMARY KEY (usage_tag_id, address_id);


--
-- TOC entry 7473 (class 2606 OID 98120)
-- Name: career_progression career_progression_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_pkey PRIMARY KEY (id);


--
-- TOC entry 7433 (class 2606 OID 93868)
-- Name: contract_allowance_deduction contract_allowance_deduction_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_allowance_deduction
    ADD CONSTRAINT contract_allowance_deduction_pkey PRIMARY KEY (id);


--
-- TOC entry 7382 (class 2606 OID 92016)
-- Name: contract_donations contract_donations_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_donations
    ADD CONSTRAINT contract_donations_pkey PRIMARY KEY (id);


--
-- TOC entry 7368 (class 2606 OID 89741)
-- Name: contract_hr_note contract_hr_note_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_hr_note
    ADD CONSTRAINT contract_hr_note_pkey PRIMARY KEY (id, created_on);


--
-- TOC entry 7427 (class 2606 OID 93783)
-- Name: contract_pay_setting contract_pay_setting_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT contract_pay_setting_pkey PRIMARY KEY (id);


--
-- TOC entry 7366 (class 2606 OID 89715)
-- Name: contract_resignation contract_resignation_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_resignation
    ADD CONSTRAINT contract_resignation_pkey PRIMARY KEY (id);


--
-- TOC entry 7435 (class 2606 OID 93910)
-- Name: contract_scheme contract_scheme_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_scheme
    ADD CONSTRAINT contract_scheme_pkey PRIMARY KEY (id);


--
-- TOC entry 7421 (class 2606 OID 93702)
-- Name: contract_service_point contract_service_point_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_service_point
    ADD CONSTRAINT contract_service_point_pkey PRIMARY KEY (id);


--
-- TOC entry 7440 (class 2606 OID 93949)
-- Name: contract_stop_payment contract_stop_payment_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_stop_payment
    ADD CONSTRAINT contract_stop_payment_pkey PRIMARY KEY (id);


--
-- TOC entry 7343 (class 2606 OID 89268)
-- Name: epm_ns_record epm_ns_record_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_pkey PRIMARY KEY (id);


--
-- TOC entry 7345 (class 2606 OID 89270)
-- Name: epm_ns_record epm_ns_record_uid_key; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_uid_key UNIQUE (uid);


--
-- TOC entry 7392 (class 2606 OID 92194)
-- Name: epm_union_info epm_union_info_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_union_info
    ADD CONSTRAINT epm_union_info_pkey PRIMARY KEY (id);


--
-- TOC entry 7394 (class 2606 OID 92196)
-- Name: epm_union_info epm_union_info_regulatory_id_key; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_union_info
    ADD CONSTRAINT epm_union_info_regulatory_id_key UNIQUE (regulatory_id);


--
-- TOC entry 7396 (class 2606 OID 92198)
-- Name: epm_union_info epm_union_info_uid_key; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_union_info
    ADD CONSTRAINT epm_union_info_uid_key UNIQUE (uid);


--
-- TOC entry 7339 (class 2606 OID 89229)
-- Name: epm_work_pass_records epm_work_pass_records_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_work_pass_records
    ADD CONSTRAINT epm_work_pass_records_pkey PRIMARY KEY (id);


--
-- TOC entry 7449 (class 2606 OID 95464)
-- Name: family_info family_info_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.family_info
    ADD CONSTRAINT family_info_pkey PRIMARY KEY (id);


--
-- TOC entry 7353 (class 2606 OID 89526)
-- Name: lk_address_type lk_address_type_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_address_type
    ADD CONSTRAINT lk_address_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7417 (class 2606 OID 93679)
-- Name: lk_amount_type lk_amount_type_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_amount_type
    ADD CONSTRAINT lk_amount_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7446 (class 2606 OID 95450)
-- Name: lk_dependent_status lk_dependent_status_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_dependent_status
    ADD CONSTRAINT lk_dependent_status_pkey PRIMARY KEY (id);


--
-- TOC entry 7380 (class 2606 OID 92004)
-- Name: lk_donation_period lk_donation_period_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_donation_period
    ADD CONSTRAINT lk_donation_period_pkey PRIMARY KEY (id);


--
-- TOC entry 7443 (class 2606 OID 95437)
-- Name: lk_family_benefit_flag lk_family_benefit_flag_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_family_benefit_flag
    ADD CONSTRAINT lk_family_benefit_flag_pkey PRIMARY KEY (id);


--
-- TOC entry 7419 (class 2606 OID 93690)
-- Name: lk_festival_advance lk_festival_advance_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_festival_advance
    ADD CONSTRAINT lk_festival_advance_pkey PRIMARY KEY (id);


--
-- TOC entry 7469 (class 2606 OID 97786)
-- Name: lk_fund_topup_type lk_fund_topup_type_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_fund_topup_type
    ADD CONSTRAINT lk_fund_topup_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7323 (class 2606 OID 89171)
-- Name: lk_pass_status lk_pass_status_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_pass_status
    ADD CONSTRAINT lk_pass_status_pkey PRIMARY KEY (id);


--
-- TOC entry 7413 (class 2606 OID 93657)
-- Name: lk_recurring_method lk_recurring_method_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_recurring_method
    ADD CONSTRAINT lk_recurring_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7357 (class 2606 OID 89548)
-- Name: lk_service_grade lk_service_grade_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_service_grade
    ADD CONSTRAINT lk_service_grade_pkey PRIMARY KEY (id);


--
-- TOC entry 7415 (class 2606 OID 93668)
-- Name: lk_service_point_period lk_service_point_period_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_service_point_period
    ADD CONSTRAINT lk_service_point_period_pkey PRIMARY KEY (id);


--
-- TOC entry 7438 (class 2606 OID 93938)
-- Name: lk_stop_payment_indicator lk_stop_payment_indicator_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_stop_payment_indicator
    ADD CONSTRAINT lk_stop_payment_indicator_pkey PRIMARY KEY (id);


--
-- TOC entry 7388 (class 2606 OID 92184)
-- Name: lk_union_worker lk_union_worker_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_union_worker
    ADD CONSTRAINT lk_union_worker_pkey PRIMARY KEY (id);


--
-- TOC entry 7390 (class 2606 OID 92186)
-- Name: lk_union_worker lk_union_worker_uid_key; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_union_worker
    ADD CONSTRAINT lk_union_worker_uid_key UNIQUE (uid);


--
-- TOC entry 7355 (class 2606 OID 89537)
-- Name: lk_usage_tag lk_usage_tag_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_usage_tag
    ADD CONSTRAINT lk_usage_tag_pkey PRIMARY KEY (id);


--
-- TOC entry 7429 (class 2606 OID 93832)
-- Name: pay_setting_work_calendar pay_setting_work_calendar_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.pay_setting_work_calendar
    ADD CONSTRAINT pay_setting_work_calendar_pkey PRIMARY KEY (id);


--
-- TOC entry 7402 (class 2606 OID 93562)
-- Name: payment_profile payment_profile_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_pkey PRIMARY KEY (id);


--
-- TOC entry 7404 (class 2606 OID 93564)
-- Name: payment_profile payment_profile_uid_key; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_uid_key UNIQUE (uid);


--
-- TOC entry 7409 (class 2606 OID 93608)
-- Name: payment_split payment_split_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_split
    ADD CONSTRAINT payment_split_pkey PRIMARY KEY (id);


--
-- TOC entry 7411 (class 2606 OID 93610)
-- Name: payment_split payment_split_uid_key; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_split
    ADD CONSTRAINT payment_split_uid_key UNIQUE (uid);


--
-- TOC entry 7425 (class 2606 OID 93730)
-- Name: service_point_payslip_message service_point_payslip_message_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.service_point_payslip_message
    ADD CONSTRAINT service_point_payslip_message_pkey PRIMARY KEY (id);


--
-- TOC entry 7423 (class 2606 OID 93704)
-- Name: contract_service_point unq_contract_service_point; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_service_point
    ADD CONSTRAINT unq_contract_service_point UNIQUE (contract_id) INCLUDE (contract_id);


--
-- TOC entry 7476 (class 2606 OID 98122)
-- Name: career_progression uq_career_progression_uid; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT uq_career_progression_uid UNIQUE (uid);


--
-- TOC entry 7341 (class 2606 OID 89231)
-- Name: epm_work_pass_records uq_epm_work_pass_records_uid; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_work_pass_records
    ADD CONSTRAINT uq_epm_work_pass_records_uid UNIQUE (uid);


--
-- TOC entry 7325 (class 2606 OID 89173)
-- Name: lk_pass_status uq_lk_pass_status_uid; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.lk_pass_status
    ADD CONSTRAINT uq_lk_pass_status_uid UNIQUE (uid);


--
-- TOC entry 7359 (class 2606 OID 105216)
-- Name: user_company_contract uq_ucc_id_user_company; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT uq_ucc_id_user_company UNIQUE (id, user_id, company_id);


--
-- TOC entry 7333 (class 2606 OID 89211)
-- Name: user_regulatory_spr uq_user_regulatory_spr_reg; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_spr
    ADD CONSTRAINT uq_user_regulatory_spr_reg UNIQUE (regulatory_id);


--
-- TOC entry 7335 (class 2606 OID 89213)
-- Name: user_regulatory_spr uq_user_regulatory_spr_uid; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_spr
    ADD CONSTRAINT uq_user_regulatory_spr_uid UNIQUE (uid);


--
-- TOC entry 7327 (class 2606 OID 89192)
-- Name: user_regulatory uq_user_regulatory_uid; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory
    ADD CONSTRAINT uq_user_regulatory_uid UNIQUE (uid);


--
-- TOC entry 7329 (class 2606 OID 89190)
-- Name: user_regulatory uq_user_regulatory_user; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory
    ADD CONSTRAINT uq_user_regulatory_user UNIQUE (user_id);


--
-- TOC entry 7364 (class 2606 OID 89679)
-- Name: user_company_address user_company_address_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_address
    ADD CONSTRAINT user_company_address_pkey PRIMARY KEY (id);


--
-- TOC entry 7463 (class 2606 OID 95720)
-- Name: user_company_asset user_company_asset_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_asset
    ADD CONSTRAINT user_company_asset_pkey PRIMARY KEY (id);


--
-- TOC entry 7361 (class 2606 OID 89581)
-- Name: user_company_contract user_company_contract_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT user_company_contract_pkey PRIMARY KEY (id);


--
-- TOC entry 7455 (class 2606 OID 95585)
-- Name: user_company_setting user_company_setting_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_setting
    ADD CONSTRAINT user_company_setting_pkey PRIMARY KEY (id);


--
-- TOC entry 7479 (class 2606 OID 98231)
-- Name: user_regulatory_commfund_topup user_regulatory_commfund_topup_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_commfund_topup
    ADD CONSTRAINT user_regulatory_commfund_topup_pkey PRIMARY KEY (id);


--
-- TOC entry 7331 (class 2606 OID 89188)
-- Name: user_regulatory user_regulatory_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory
    ADD CONSTRAINT user_regulatory_pkey PRIMARY KEY (id);


--
-- TOC entry 7337 (class 2606 OID 89209)
-- Name: user_regulatory_spr user_regulatory_spr_pkey; Type: CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_spr
    ADD CONSTRAINT user_regulatory_spr_pkey PRIMARY KEY (id);


--
-- TOC entry 7209 (class 2606 OID 73757)
-- Name: lk_leave_type lk_leave_type_uid_key; Type: CONSTRAINT; Schema: leave; Owner: timesadmin
--

ALTER TABLE ONLY leave.lk_leave_type
    ADD CONSTRAINT lk_leave_type_uid_key UNIQUE (uid);


--
-- TOC entry 7211 (class 2606 OID 73755)
-- Name: lk_leave_type lk_prorate_formula_pkey; Type: CONSTRAINT; Schema: leave; Owner: timesadmin
--

ALTER TABLE ONLY leave.lk_leave_type
    ADD CONSTRAINT lk_prorate_formula_pkey PRIMARY KEY (id);


--
-- TOC entry 7185 (class 2606 OID 70219)
-- Name: mso company_mso_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.mso
    ADD CONSTRAINT company_mso_pkey PRIMARY KEY (id);


--
-- TOC entry 7133 (class 2606 OID 62470)
-- Name: lk_encashment_method encashment_method_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_encashment_method
    ADD CONSTRAINT encashment_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7117 (class 2606 OID 62255)
-- Name: lk_mvc_method lk_mvc_method_name_key; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_mvc_method
    ADD CONSTRAINT lk_mvc_method_name_key UNIQUE (name);


--
-- TOC entry 7119 (class 2606 OID 62253)
-- Name: lk_mvc_method lk_mvc_method_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_mvc_method
    ADD CONSTRAINT lk_mvc_method_pkey PRIMARY KEY (id);


--
-- TOC entry 7121 (class 2606 OID 62257)
-- Name: lk_mvc_method lk_mvc_method_uid_key; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_mvc_method
    ADD CONSTRAINT lk_mvc_method_uid_key UNIQUE (uid);


--
-- TOC entry 7123 (class 2606 OID 62270)
-- Name: lk_mvc_scheme lk_mvc_scheme_name_key; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_mvc_scheme
    ADD CONSTRAINT lk_mvc_scheme_name_key UNIQUE (name);


--
-- TOC entry 7125 (class 2606 OID 62268)
-- Name: lk_mvc_scheme lk_mvc_scheme_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_mvc_scheme
    ADD CONSTRAINT lk_mvc_scheme_pkey PRIMARY KEY (id);


--
-- TOC entry 7127 (class 2606 OID 62272)
-- Name: lk_mvc_scheme lk_mvc_scheme_uid_key; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_mvc_scheme
    ADD CONSTRAINT lk_mvc_scheme_uid_key UNIQUE (uid);


--
-- TOC entry 7540 (class 2606 OID 107073)
-- Name: lk_pay_run_status lk_pay_run_status_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_pay_run_status
    ADD CONSTRAINT lk_pay_run_status_pkey PRIMARY KEY (id);


--
-- TOC entry 7431 (class 2606 OID 93850)
-- Name: lk_payroll_cycle lk_payroll_cycle_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.lk_payroll_cycle
    ADD CONSTRAINT lk_payroll_cycle_pkey PRIMARY KEY (id);


--
-- TOC entry 7129 (class 2606 OID 62327)
-- Name: mvc mvc_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.mvc
    ADD CONSTRAINT mvc_pkey PRIMARY KEY (id);


--
-- TOC entry 7558 (class 2606 OID 110917)
-- Name: pay_period_contribution pay_period_contribution_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_period_contribution
    ADD CONSTRAINT pay_period_contribution_pkey PRIMARY KEY (id);


--
-- TOC entry 7554 (class 2606 OID 108147)
-- Name: pay_period pay_period_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_period
    ADD CONSTRAINT pay_period_pkey PRIMARY KEY (id);


--
-- TOC entry 7556 (class 2606 OID 110716)
-- Name: pay_record_modification pay_record_modification_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_record_modification
    ADD CONSTRAINT pay_record_modification_pkey PRIMARY KEY (pay_record_id);


--
-- TOC entry 7544 (class 2606 OID 107151)
-- Name: pay_record pay_record_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_record
    ADD CONSTRAINT pay_record_pkey PRIMARY KEY (id);


--
-- TOC entry 7542 (class 2606 OID 107100)
-- Name: pay_run pay_run_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_run
    ADD CONSTRAINT pay_run_pkey PRIMARY KEY (id);


--
-- TOC entry 7135 (class 2606 OID 62486)
-- Name: encashment_policy pkey_encashment_policy; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.encashment_policy
    ADD CONSTRAINT pkey_encashment_policy PRIMARY KEY (id);


--
-- TOC entry 7139 (class 2606 OID 62879)
-- Name: rounding_formula rounding_formula_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.rounding_formula
    ADD CONSTRAINT rounding_formula_pkey PRIMARY KEY (id);


--
-- TOC entry 7031 (class 2606 OID 57655)
-- Name: sg_payroll_settings sg_payroll_settings_pkey; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.sg_payroll_settings
    ADD CONSTRAINT sg_payroll_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 7560 (class 2606 OID 112643)
-- Name: pay_period_contribution uq_pay_period_contribution_period_user; Type: CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_period_contribution
    ADD CONSTRAINT uq_pay_period_contribution_period_user UNIQUE (pay_period_id, user_id);


--
-- TOC entry 6958 (class 2606 OID 49464)
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: timesadmin
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- TOC entry 7016 (class 2606 OID 56193)
-- Name: guided_onboarding guided_onboarding_pkey; Type: CONSTRAINT; Schema: public; Owner: timesadmin
--

ALTER TABLE ONLY public.guided_onboarding
    ADD CONSTRAINT guided_onboarding_pkey PRIMARY KEY (code);


--
-- TOC entry 6996 (class 2606 OID 52299)
-- Name: access_rules access_rules_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.access_rules
    ADD CONSTRAINT access_rules_pkey PRIMARY KEY (id);


--
-- TOC entry 7319 (class 2606 OID 84153)
-- Name: address_usage_type address_usage_type_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.address_usage_type
    ADD CONSTRAINT address_usage_type_pkey PRIMARY KEY (usage_tag_id, address_id);


--
-- TOC entry 7510 (class 2606 OID 102165)
-- Name: application_settings application_settings_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.application_settings
    ADD CONSTRAINT application_settings_pkey PRIMARY KEY (id);


--
-- TOC entry 7351 (class 2606 OID 89498)
-- Name: contract_hr_note contract_hr_note_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.contract_hr_note
    ADD CONSTRAINT contract_hr_note_pkey PRIMARY KEY (id, created_on);


--
-- TOC entry 7349 (class 2606 OID 89472)
-- Name: contract_resignation contract_resignation_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.contract_resignation
    ADD CONSTRAINT contract_resignation_pkey PRIMARY KEY (id);


--
-- TOC entry 7491 (class 2606 OID 100525)
-- Name: data_model_field data_model_field_final_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.data_model_field
    ADD CONSTRAINT data_model_field_final_pkey PRIMARY KEY (id);


--
-- TOC entry 7489 (class 2606 OID 100501)
-- Name: data_security_rules data_security_rules_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.data_security_rules
    ADD CONSTRAINT data_security_rules_pkey PRIMARY KEY (id);


--
-- TOC entry 7173 (class 2606 OID 65615)
-- Name: disabled_roles disabled_roles_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.disabled_roles
    ADD CONSTRAINT disabled_roles_pkey PRIMARY KEY (role_id, disabled_role_id);


--
-- TOC entry 6976 (class 2606 OID 52170)
-- Name: feature feature_code_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature
    ADD CONSTRAINT feature_code_key UNIQUE (code);


--
-- TOC entry 7514 (class 2606 OID 102510)
-- Name: feature_group feature_group_code_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature_group
    ADD CONSTRAINT feature_group_code_key UNIQUE (code);


--
-- TOC entry 7516 (class 2606 OID 102508)
-- Name: feature_group feature_group_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature_group
    ADD CONSTRAINT feature_group_pkey PRIMARY KEY (id);


--
-- TOC entry 6988 (class 2606 OID 52201)
-- Name: feature_permission feature_permission_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature_permission
    ADD CONSTRAINT feature_permission_pkey PRIMARY KEY (feature_id, permission_id);


--
-- TOC entry 6978 (class 2606 OID 52168)
-- Name: feature feature_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature
    ADD CONSTRAINT feature_pkey PRIMARY KEY (id);


--
-- TOC entry 6980 (class 2606 OID 52183)
-- Name: field field_code_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.field
    ADD CONSTRAINT field_code_key UNIQUE (code);


--
-- TOC entry 6990 (class 2606 OID 52216)
-- Name: field_permission field_permission_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.field_permission
    ADD CONSTRAINT field_permission_pkey PRIMARY KEY (field_id, permission_id);


--
-- TOC entry 6982 (class 2606 OID 52181)
-- Name: field field_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.field
    ADD CONSTRAINT field_pkey PRIMARY KEY (id);


--
-- TOC entry 6972 (class 2606 OID 52142)
-- Name: function function_code_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.function
    ADD CONSTRAINT function_code_key UNIQUE (code);


--
-- TOC entry 6974 (class 2606 OID 52140)
-- Name: function function_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.function
    ADD CONSTRAINT function_pkey PRIMARY KEY (id);


--
-- TOC entry 7002 (class 2606 OID 52423)
-- Name: left_menu_item left_menu_item_menu_item_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.left_menu_item
    ADD CONSTRAINT left_menu_item_menu_item_key UNIQUE (menu_item);


--
-- TOC entry 7004 (class 2606 OID 52421)
-- Name: left_menu_item left_menu_item_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.left_menu_item
    ADD CONSTRAINT left_menu_item_pkey PRIMARY KEY (module_code, menu_item);


--
-- TOC entry 7522 (class 2606 OID 104087)
-- Name: link_expiry_details link_expiry_details_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.link_expiry_details
    ADD CONSTRAINT link_expiry_details_pkey PRIMARY KEY (id);


--
-- TOC entry 7317 (class 2606 OID 84107)
-- Name: lk_address_type lk_address_type_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.lk_address_type
    ADD CONSTRAINT lk_address_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7487 (class 2606 OID 100489)
-- Name: lk_data_field_data_type lk_data_field_data_type_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.lk_data_field_data_type
    ADD CONSTRAINT lk_data_field_data_type_pkey PRIMARY KEY (id);


--
-- TOC entry 7498 (class 2606 OID 101412)
-- Name: lk_data_model lk_data_model_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.lk_data_model
    ADD CONSTRAINT lk_data_model_pkey PRIMARY KEY (id);


--
-- TOC entry 7485 (class 2606 OID 100469)
-- Name: lk_query_operator lk_query_operator_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.lk_query_operator
    ADD CONSTRAINT lk_query_operator_pkey PRIMARY KEY (id);


--
-- TOC entry 7347 (class 2606 OID 89395)
-- Name: lk_service_grade lk_service_grade_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.lk_service_grade
    ADD CONSTRAINT lk_service_grade_pkey PRIMARY KEY (id);


--
-- TOC entry 7315 (class 2606 OID 84096)
-- Name: lk_usage_tag lk_usage_tag_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.lk_usage_tag
    ADD CONSTRAINT lk_usage_tag_pkey PRIMARY KEY (id);


--
-- TOC entry 7508 (class 2606 OID 101515)
-- Name: mobile_secret_key mobile_secret_key_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.mobile_secret_key
    ADD CONSTRAINT mobile_secret_key_pkey PRIMARY KEY (id);


--
-- TOC entry 7000 (class 2606 OID 52414)
-- Name: notification_log notification_log_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.notification_log
    ADD CONSTRAINT notification_log_pkey PRIMARY KEY (id);


--
-- TOC entry 7311 (class 2606 OID 84026)
-- Name: other_access other_access_code_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.other_access
    ADD CONSTRAINT other_access_code_key UNIQUE (code);


--
-- TOC entry 7313 (class 2606 OID 84024)
-- Name: other_access other_access_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.other_access
    ADD CONSTRAINT other_access_pkey PRIMARY KEY (id);


--
-- TOC entry 7518 (class 2606 OID 103462)
-- Name: password_reset_code password_reset_code_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.password_reset_code
    ADD CONSTRAINT password_reset_code_pkey PRIMARY KEY (id);


--
-- TOC entry 6984 (class 2606 OID 52196)
-- Name: permission permission_code_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.permission
    ADD CONSTRAINT permission_code_key UNIQUE (code);


--
-- TOC entry 6986 (class 2606 OID 52194)
-- Name: permission permission_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.permission
    ADD CONSTRAINT permission_pkey PRIMARY KEY (id);


--
-- TOC entry 7552 (class 2606 OID 107430)
-- Name: privacy_security_rule_employees pk_privacy_security_rule_employees; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.privacy_security_rule_employees
    ADD CONSTRAINT pk_privacy_security_rule_employees PRIMARY KEY (rule_id, target_user_id);


--
-- TOC entry 7465 (class 2606 OID 95738)
-- Name: verification_code pk_verification_code; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.verification_code
    ADD CONSTRAINT pk_verification_code PRIMARY KEY (target_id, purpose);


--
-- TOC entry 7547 (class 2606 OID 107412)
-- Name: privacy_security_rules privacy_security_rules_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.privacy_security_rules
    ADD CONSTRAINT privacy_security_rules_pkey PRIMARY KEY (id);


--
-- TOC entry 7177 (class 2606 OID 66838)
-- Name: rate_limit_type rate_limit_type_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.rate_limit_type
    ADD CONSTRAINT rate_limit_type_pkey PRIMARY KEY (code);


--
-- TOC entry 6998 (class 2606 OID 52327)
-- Name: role_function role_function_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_function
    ADD CONSTRAINT role_function_pkey PRIMARY KEY (role_id, function_id);


--
-- TOC entry 6968 (class 2606 OID 52134)
-- Name: role role_name_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role
    ADD CONSTRAINT role_name_key UNIQUE (name);


--
-- TOC entry 6970 (class 2606 OID 52132)
-- Name: role role_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (id);


--
-- TOC entry 7562 (class 2606 OID 110950)
-- Name: role_transfer_request role_transfer_request_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_transfer_request
    ADD CONSTRAINT role_transfer_request_pkey PRIMARY KEY (id);


--
-- TOC entry 7321 (class 2606 OID 85561)
-- Name: session_idle_time_old session_idle_time_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.session_idle_time_old
    ADD CONSTRAINT session_idle_time_pkey PRIMARY KEY (id);


--
-- TOC entry 7512 (class 2606 OID 103820)
-- Name: application_settings uq_application_settings_setting_name; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.application_settings
    ADD CONSTRAINT uq_application_settings_setting_name UNIQUE (setting_name);


--
-- TOC entry 7520 (class 2606 OID 103464)
-- Name: password_reset_code uq_password_reset_code_target_purpose; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.password_reset_code
    ADD CONSTRAINT uq_password_reset_code_target_purpose UNIQUE (target_id, purpose);


--
-- TOC entry 7549 (class 2606 OID 107414)
-- Name: privacy_security_rules uq_privacy_security_rules_user_company; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.privacy_security_rules
    ADD CONSTRAINT uq_privacy_security_rules_user_company UNIQUE (user_id, company_id);


--
-- TOC entry 7179 (class 2606 OID 66857)
-- Name: rate_limit_log uq_rate_limit_log_user_code; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.rate_limit_log
    ADD CONSTRAINT uq_rate_limit_log_user_code UNIQUE (user_id, code);


--
-- TOC entry 6962 (class 2606 OID 104149)
-- Name: user uq_user_username; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security."user"
    ADD CONSTRAINT uq_user_username UNIQUE (username);


--
-- TOC entry 6966 (class 2606 OID 52113)
-- Name: user_company user_company_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company
    ADD CONSTRAINT user_company_pkey PRIMARY KEY (user_id, company_id);


--
-- TOC entry 7175 (class 2606 OID 65655)
-- Name: user_company_role_function user_company_role_function_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role_function
    ADD CONSTRAINT user_company_role_function_pkey PRIMARY KEY (user_id, company_id, role_id);


--
-- TOC entry 6992 (class 2606 OID 52235)
-- Name: user_company_role user_company_role_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role
    ADD CONSTRAINT user_company_role_pkey PRIMARY KEY (user_id, company_id, role_id);


--
-- TOC entry 7303 (class 2606 OID 79998)
-- Name: user_identity user_identity_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT user_identity_pkey PRIMARY KEY (id);


--
-- TOC entry 7305 (class 2606 OID 80000)
-- Name: user_identity user_identity_uid_key; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT user_identity_uid_key UNIQUE (uid);


--
-- TOC entry 6964 (class 2606 OID 52102)
-- Name: user user_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- TOC entry 6994 (class 2606 OID 52264)
-- Name: user_role user_role_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_role
    ADD CONSTRAINT user_role_pkey PRIMARY KEY (user_id, role_id);


--
-- TOC entry 7006 (class 2606 OID 55762)
-- Name: user_role_status user_role_status_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_role_status
    ADD CONSTRAINT user_role_status_pkey PRIMARY KEY (id);


--
-- TOC entry 7018 (class 2606 OID 56395)
-- Name: user_status user_status_pkey; Type: CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_status
    ADD CONSTRAINT user_status_pkey PRIMARY KEY (id);


--
-- TOC entry 6916 (class 2606 OID 49205)
-- Name: activity_type activity_type_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.activity_type
    ADD CONSTRAINT activity_type_pkey PRIMARY KEY (id);


--
-- TOC entry 6946 (class 2606 OID 49165)
-- Name: cancellation_reason cancellation_reason_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_reason
    ADD CONSTRAINT cancellation_reason_pkey PRIMARY KEY (id);


--
-- TOC entry 6948 (class 2606 OID 49167)
-- Name: cancellation_reason cancellation_reason_reason_key; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_reason
    ADD CONSTRAINT cancellation_reason_reason_key UNIQUE (reason);


--
-- TOC entry 6950 (class 2606 OID 49169)
-- Name: cancellation_reason cancellation_reason_uid_key; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_reason
    ADD CONSTRAINT cancellation_reason_uid_key UNIQUE (uid);


--
-- TOC entry 6956 (class 2606 OID 49197)
-- Name: cancellation_request_documents cancellation_request_documents_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_request_documents
    ADD CONSTRAINT cancellation_request_documents_pkey PRIMARY KEY (id);


--
-- TOC entry 6952 (class 2606 OID 49180)
-- Name: cancellation_request cancellation_request_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_request
    ADD CONSTRAINT cancellation_request_pkey PRIMARY KEY (id);


--
-- TOC entry 6954 (class 2606 OID 49182)
-- Name: cancellation_request cancellation_request_uid_key; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_request
    ADD CONSTRAINT cancellation_request_uid_key UNIQUE (uid);


--
-- TOC entry 6914 (class 2606 OID 49134)
-- Name: item item_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- TOC entry 6960 (class 2606 OID 51891)
-- Name: licensing_plan_module licensing_plan_module_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.licensing_plan_module
    ADD CONSTRAINT licensing_plan_module_pkey PRIMARY KEY (id);


--
-- TOC entry 6912 (class 2606 OID 49100)
-- Name: licensing_plan licensing_plan_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.licensing_plan
    ADD CONSTRAINT licensing_plan_pkey PRIMARY KEY (id);


--
-- TOC entry 6938 (class 2606 OID 46919)
-- Name: order_detail order_detail_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.order_detail
    ADD CONSTRAINT order_detail_pkey PRIMARY KEY (id);


--
-- TOC entry 6936 (class 2606 OID 39116)
-- Name: payment_frequency_discount payment_frequency_discount_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.payment_frequency_discount
    ADD CONSTRAINT payment_frequency_discount_pkey PRIMARY KEY (id);


--
-- TOC entry 6918 (class 2606 OID 49075)
-- Name: payment_frequency payment_frequency_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.payment_frequency
    ADD CONSTRAINT payment_frequency_pkey PRIMARY KEY (id);


--
-- TOC entry 6920 (class 2606 OID 49061)
-- Name: payment_status payment_status_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.payment_status
    ADD CONSTRAINT payment_status_pkey PRIMARY KEY (id);


--
-- TOC entry 7014 (class 2606 OID 55910)
-- Name: subscription_transaction_document pkey_sub_trx_doc; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_transaction_document
    ADD CONSTRAINT pkey_sub_trx_doc PRIMARY KEY (id);


--
-- TOC entry 6922 (class 2606 OID 49042)
-- Name: price_item price_item_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.price_item
    ADD CONSTRAINT price_item_pkey PRIMARY KEY (id);


--
-- TOC entry 6926 (class 2606 OID 48979)
-- Name: subscription_contract subscription_contract_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_contract
    ADD CONSTRAINT subscription_contract_pkey PRIMARY KEY (id);


--
-- TOC entry 6928 (class 2606 OID 48959)
-- Name: subscription_contract_schedule subscription_contract_schedule_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_contract_schedule
    ADD CONSTRAINT subscription_contract_schedule_pkey PRIMARY KEY (id);


--
-- TOC entry 6942 (class 2606 OID 46970)
-- Name: subscription_invoice subscription_invoice_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_invoice
    ADD CONSTRAINT subscription_invoice_pkey PRIMARY KEY (id);


--
-- TOC entry 6924 (class 2606 OID 49019)
-- Name: subscription subscription_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription
    ADD CONSTRAINT subscription_pkey PRIMARY KEY (id);


--
-- TOC entry 6930 (class 2606 OID 48934)
-- Name: subscription_pricing subscription_pricing_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_pricing
    ADD CONSTRAINT subscription_pricing_pkey PRIMARY KEY (id);


--
-- TOC entry 6932 (class 2606 OID 48924)
-- Name: subscription_status subscription_status_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_status
    ADD CONSTRAINT subscription_status_pkey PRIMARY KEY (id);


--
-- TOC entry 6940 (class 2606 OID 46945)
-- Name: subscription_transaction subscription_transaction_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_transaction
    ADD CONSTRAINT subscription_transaction_pkey PRIMARY KEY (id);


--
-- TOC entry 6944 (class 2606 OID 46980)
-- Name: subscription_usage subscription_usage_pkey; Type: CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_usage
    ADD CONSTRAINT subscription_usage_pkey PRIMARY KEY (id);


--
-- TOC entry 6856 (class 1259 OID 82679)
-- Name: company_code_unique_active; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE UNIQUE INDEX company_code_unique_active ON company.company USING btree (code) WHERE (is_deleted = false);


--
-- TOC entry 6857 (class 1259 OID 82678)
-- Name: company_uen_unique_active; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE UNIQUE INDEX company_uen_unique_active ON company.company USING btree (uen) WHERE (is_deleted = false);


--
-- TOC entry 6886 (class 1259 OID 36792)
-- Name: idx_my_provident_fund_company_bank_id; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_my_provident_fund_company_bank_id ON company.my_provident_fund USING btree (company_bank_id);


--
-- TOC entry 6887 (class 1259 OID 36793)
-- Name: idx_my_provident_fund_created_on; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_my_provident_fund_created_on ON company.my_provident_fund USING btree (created_on);


--
-- TOC entry 6888 (class 1259 OID 36794)
-- Name: idx_my_provident_fund_id; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE UNIQUE INDEX idx_my_provident_fund_id ON company.my_provident_fund USING btree (id);


--
-- TOC entry 6889 (class 1259 OID 36795)
-- Name: idx_my_provident_fund_uid; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_my_provident_fund_uid ON company.my_provident_fund USING btree (uid);


--
-- TOC entry 6890 (class 1259 OID 36796)
-- Name: idx_my_provident_fund_updated_on; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_my_provident_fund_updated_on ON company.my_provident_fund USING btree (updated_on);


--
-- TOC entry 7501 (class 1259 OID 101502)
-- Name: idx_rule_user_rule; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_rule_user_rule ON company.query_builder_rule_users USING btree (rule_id);


--
-- TOC entry 7502 (class 1259 OID 101503)
-- Name: idx_rule_user_user; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_rule_user_user ON company.query_builder_rule_users USING btree (user_id);


--
-- TOC entry 6899 (class 1259 OID 36835)
-- Name: idx_sg_provident_fund_company_bank_id; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_sg_provident_fund_company_bank_id ON company.sg_provident_fund USING btree (company_bank_id);


--
-- TOC entry 6900 (class 1259 OID 101718)
-- Name: idx_sg_provident_fund_cpf_number; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_sg_provident_fund_cpf_number ON company.sg_provident_fund USING btree (cpf_number);


--
-- TOC entry 6901 (class 1259 OID 36837)
-- Name: idx_sg_provident_fund_id; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE UNIQUE INDEX idx_sg_provident_fund_id ON company.sg_provident_fund USING btree (id);


--
-- TOC entry 6902 (class 1259 OID 36838)
-- Name: idx_sg_provident_fund_income_tax_number; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_sg_provident_fund_income_tax_number ON company.sg_provident_fund USING btree (income_tax_number);


--
-- TOC entry 6903 (class 1259 OID 36839)
-- Name: idx_sg_provident_fund_uid; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_sg_provident_fund_uid ON company.sg_provident_fund USING btree (uid);


--
-- TOC entry 6904 (class 1259 OID 36840)
-- Name: idx_sg_provident_fund_voluntary_account; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX idx_sg_provident_fund_voluntary_account ON company.sg_provident_fund USING btree (voluntary_account_number);


--
-- TOC entry 7023 (class 1259 OID 110748)
-- Name: ix_code_setup_company_type_country; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX ix_code_setup_company_type_country ON company.code_setup USING btree (company_id, code_setup_type_id, country_id);


--
-- TOC entry 7565 (class 1259 OID 112760)
-- Name: ix_document_favourite_document; Type: INDEX; Schema: company; Owner: timesadmin
--

CREATE INDEX ix_document_favourite_document ON company.document_favourite USING btree (document_id);


--
-- TOC entry 7436 (class 1259 OID 93926)
-- Name: idx_contract_scheme_scheme_type; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX idx_contract_scheme_scheme_type ON employee.contract_scheme USING btree (scheme_type);


--
-- TOC entry 7441 (class 1259 OID 93960)
-- Name: idx_contract_stop_payment_indicator; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX idx_contract_stop_payment_indicator ON employee.contract_stop_payment USING btree (stop_payment_indicator_id) WITH (fillfactor='100', deduplicate_items='true');


--
-- TOC entry 7452 (class 1259 OID 95559)
-- Name: idx_edu_type; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX idx_edu_type ON employee.user_company_education USING btree (type);


--
-- TOC entry 7477 (class 1259 OID 98247)
-- Name: idx_user_regulatory_commfund_key1; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX idx_user_regulatory_commfund_key1 ON employee.user_regulatory_commfund_topup USING btree (user_id, company_id, commfund_number, commfund_code);


--
-- TOC entry 7474 (class 1259 OID 98213)
-- Name: ix_career_progression_contract_sort; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX ix_career_progression_contract_sort ON employee.career_progression USING btree (contract_id, effective_date DESC, pay_effective_date DESC, created_on DESC);


--
-- TOC entry 7450 (class 1259 OID 105207)
-- Name: ix_family_info_user; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX ix_family_info_user ON employee.family_info USING btree (user_id);


--
-- TOC entry 7407 (class 1259 OID 93631)
-- Name: ix_payment_split_payment_profile_id; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX ix_payment_split_payment_profile_id ON employee.payment_split USING btree (payment_profile_id);


--
-- TOC entry 7362 (class 1259 OID 105208)
-- Name: ix_user_company_address_user; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX ix_user_company_address_user ON employee.user_company_address USING btree (user_id);


--
-- TOC entry 7453 (class 1259 OID 105209)
-- Name: ix_user_company_education_user; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE INDEX ix_user_company_education_user ON employee.user_company_education USING btree (user_id);


--
-- TOC entry 7451 (class 1259 OID 95495)
-- Name: uq_family_info_uid; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE UNIQUE INDEX uq_family_info_uid ON employee.family_info USING btree (uid);


--
-- TOC entry 7447 (class 1259 OID 95451)
-- Name: uq_lk_dependent_status_uid; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE UNIQUE INDEX uq_lk_dependent_status_uid ON employee.lk_dependent_status USING btree (uid);


--
-- TOC entry 7444 (class 1259 OID 95438)
-- Name: uq_lk_family_benefit_flag_uid; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE UNIQUE INDEX uq_lk_family_benefit_flag_uid ON employee.lk_family_benefit_flag USING btree (uid);


--
-- TOC entry 7405 (class 1259 OID 105222)
-- Name: uq_payment_profile_one_preferred_per_company; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE UNIQUE INDEX uq_payment_profile_one_preferred_per_company ON employee.payment_profile USING btree (user_id, company_id) WHERE (is_preferred = true);


--
-- TOC entry 7406 (class 1259 OID 93595)
-- Name: uq_payment_profile_one_preferred_per_user; Type: INDEX; Schema: employee; Owner: timesadmin
--

CREATE UNIQUE INDEX uq_payment_profile_one_preferred_per_user ON employee.payment_profile USING btree (user_id) WHERE (is_preferred = true);


--
-- TOC entry 7545 (class 1259 OID 109037)
-- Name: ux_pay_record_run_user_contract; Type: INDEX; Schema: payroll; Owner: timesadmin
--

CREATE UNIQUE INDEX ux_pay_record_run_user_contract ON payroll.pay_record USING btree (pay_run_id, user_id, contract_id);


--
-- TOC entry 7492 (class 1259 OID 100526)
-- Name: idx_dmf_final_data_model_id; Type: INDEX; Schema: security; Owner: timesadmin
--

CREATE INDEX idx_dmf_final_data_model_id ON security.data_model_field USING btree (data_model_id);


--
-- TOC entry 7493 (class 1259 OID 100527)
-- Name: idx_dmf_final_field_key; Type: INDEX; Schema: security; Owner: timesadmin
--

CREATE UNIQUE INDEX idx_dmf_final_field_key ON security.data_model_field USING btree (field_key) WHERE (field_key IS NOT NULL);


--
-- TOC entry 7494 (class 1259 OID 100528)
-- Name: idx_dmf_final_is_active; Type: INDEX; Schema: security; Owner: timesadmin
--

CREATE INDEX idx_dmf_final_is_active ON security.data_model_field USING btree (is_active);


--
-- TOC entry 7550 (class 1259 OID 107441)
-- Name: ix_privacy_security_rule_employees_target_user; Type: INDEX; Schema: security; Owner: timesadmin
--

CREATE INDEX ix_privacy_security_rule_employees_target_user ON security.privacy_security_rule_employees USING btree (target_user_id);


--
-- TOC entry 7977 (class 2620 OID 89700)
-- Name: user_company_address trg_enforce_single_default_address; Type: TRIGGER; Schema: employee; Owner: timesadmin
--

CREATE TRIGGER trg_enforce_single_default_address BEFORE INSERT OR UPDATE ON employee.user_company_address FOR EACH ROW EXECUTE FUNCTION employee.set_single_default_address();


--
-- TOC entry 7978 (class 2620 OID 107524)
-- Name: pay_run trg_pay_run_set_code; Type: TRIGGER; Schema: payroll; Owner: timesadmin
--

CREATE TRIGGER trg_pay_run_set_code BEFORE INSERT ON payroll.pay_run FOR EACH ROW EXECUTE FUNCTION payroll.fn_pay_run_set_code();


--
-- TOC entry 7976 (class 2620 OID 80585)
-- Name: user trg_set_full_name; Type: TRIGGER; Schema: security; Owner: timesadmin
--

CREATE TRIGGER trg_set_full_name BEFORE INSERT ON security."user" FOR EACH ROW EXECUTE FUNCTION security.auto_set_full_name();


--
-- TOC entry 7667 (class 2606 OID 70281)
-- Name: allowance_deduction allowance_deduction_backpay_allowance_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_backpay_allowance_id_fkey FOREIGN KEY (backpay_allowance_id) REFERENCES company.allowance_deduction(id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 7668 (class 2606 OID 60803)
-- Name: allowance_deduction allowance_deduction_benefit_in_kind_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_benefit_in_kind_id_fkey FOREIGN KEY (benefit_in_kind_id) REFERENCES company.allowance_deduction_benefit_in_kind(id);


--
-- TOC entry 7669 (class 2606 OID 60778)
-- Name: allowance_deduction allowance_deduction_bonus_type_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_bonus_type_id_fkey FOREIGN KEY (bonus_type_id) REFERENCES company.allowance_deduction_bonus_type(id);


--
-- TOC entry 7670 (class 2606 OID 63826)
-- Name: allowance_deduction allowance_deduction_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7671 (class 2606 OID 60768)
-- Name: allowance_deduction allowance_deduction_cpf_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_cpf_id_fkey FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id);


--
-- TOC entry 7672 (class 2606 OID 60783)
-- Name: allowance_deduction allowance_deduction_gross_wage_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_gross_wage_id_fkey FOREIGN KEY (gross_wage_id) REFERENCES company.allowance_deduction_gross_wage(id);


--
-- TOC entry 7673 (class 2606 OID 60798)
-- Name: allowance_deduction allowance_deduction_grp_formula_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_grp_formula_id_fkey FOREIGN KEY (grp_formula_id) REFERENCES company.allowance_deduction_grp_formula(id);


--
-- TOC entry 7674 (class 2606 OID 60763)
-- Name: allowance_deduction allowance_deduction_tax_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_tax_id_fkey FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id);


--
-- TOC entry 7675 (class 2606 OID 60773)
-- Name: allowance_deduction allowance_deduction_type_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_type_id_fkey FOREIGN KEY (type_id) REFERENCES company.allowance_deduction_type(id);


--
-- TOC entry 7676 (class 2606 OID 60793)
-- Name: allowance_deduction allowance_deduction_unit_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.allowance_deduction
    ADD CONSTRAINT allowance_deduction_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES company.allowance_deduction_unit(id);


--
-- TOC entry 7566 (class 2606 OID 48410)
-- Name: bank bank_area_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank
    ADD CONSTRAINT bank_area_fkey FOREIGN KEY (area_id) REFERENCES company.area(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7567 (class 2606 OID 35562)
-- Name: bank bank_bank_category_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank
    ADD CONSTRAINT bank_bank_category_id_fkey FOREIGN KEY (bank_category_id) REFERENCES company.bank_category(id) ON DELETE CASCADE;


--
-- TOC entry 7568 (class 2606 OID 35582)
-- Name: bank_branch bank_branch_bank_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.bank_branch
    ADD CONSTRAINT bank_branch_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES company.bank(id) ON DELETE CASCADE;


--
-- TOC entry 7763 (class 2606 OID 75628)
-- Name: claim_financial_period claim_financial_period_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.claim_financial_period
    ADD CONSTRAINT claim_financial_period_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7774 (class 2606 OID 78137)
-- Name: sg_community_fund_setup comm_fund_backpay_allowance_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_backpay_allowance_fkey FOREIGN KEY (backpay_allowance_id) REFERENCES company.allowance_deduction(id) ON DELETE SET NULL;


--
-- TOC entry 7775 (class 2606 OID 78142)
-- Name: sg_community_fund_setup comm_fund_benefit_in_kind_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_benefit_in_kind_fkey FOREIGN KEY (benefit_in_kind_id) REFERENCES company.allowance_deduction_benefit_in_kind(id) ON DELETE CASCADE;


--
-- TOC entry 7776 (class 2606 OID 78147)
-- Name: sg_community_fund_setup comm_fund_bonus_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_bonus_type_fkey FOREIGN KEY (bonus_type_id) REFERENCES company.allowance_deduction_bonus_type(id) ON DELETE SET NULL;


--
-- TOC entry 7777 (class 2606 OID 78152)
-- Name: sg_community_fund_setup comm_fund_category; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_category FOREIGN KEY (category_id) REFERENCES company.lk_community_fund_category(id) ON DELETE CASCADE;


--
-- TOC entry 7778 (class 2606 OID 78157)
-- Name: sg_community_fund_setup comm_fund_cpf_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_cpf_fkey FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7779 (class 2606 OID 78162)
-- Name: sg_community_fund_setup comm_fund_gross_wage_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_gross_wage_fkey FOREIGN KEY (gross_wage_id) REFERENCES company.allowance_deduction_gross_wage(id) ON DELETE SET NULL;


--
-- TOC entry 7780 (class 2606 OID 78167)
-- Name: sg_community_fund_setup comm_fund_grp_formula_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_grp_formula_fkey FOREIGN KEY (grp_formula_id) REFERENCES company.allowance_deduction_grp_formula(id) ON DELETE SET NULL;


--
-- TOC entry 7781 (class 2606 OID 78172)
-- Name: sg_community_fund_setup comm_fund_tax_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_tax_fkey FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id) ON DELETE CASCADE;


--
-- TOC entry 7782 (class 2606 OID 78177)
-- Name: sg_community_fund_setup comm_fund_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_type_fkey FOREIGN KEY (type_id) REFERENCES company.allowance_deduction_type(id) ON DELETE CASCADE;


--
-- TOC entry 7783 (class 2606 OID 78182)
-- Name: sg_community_fund_setup comm_fund_unit_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT comm_fund_unit_fkey FOREIGN KEY (unit_id) REFERENCES company.allowance_deduction_unit(id) ON DELETE SET NULL;


--
-- TOC entry 7596 (class 2606 OID 37111)
-- Name: company_address_info_kiv company_address_info_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_address_info_kiv
    ADD CONSTRAINT company_address_info_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id);


--
-- TOC entry 7597 (class 2606 OID 37116)
-- Name: company_address_info_kiv company_address_info_country_city_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_address_info_kiv
    ADD CONSTRAINT company_address_info_country_city_id_fkey FOREIGN KEY (country_city_id) REFERENCES company.country_city(id);


--
-- TOC entry 7598 (class 2606 OID 37121)
-- Name: company_address_info_kiv company_address_info_country_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_address_info_kiv
    ADD CONSTRAINT company_address_info_country_id_fkey FOREIGN KEY (country_id) REFERENCES company.country(id);


--
-- TOC entry 7599 (class 2606 OID 37126)
-- Name: company_address_info_kiv company_address_info_country_state_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_address_info_kiv
    ADD CONSTRAINT company_address_info_country_state_id_fkey FOREIGN KEY (country_state_id) REFERENCES company.country_state(id);


--
-- TOC entry 7576 (class 2606 OID 48849)
-- Name: company_bank company_bank_bank_branch_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_bank
    ADD CONSTRAINT company_bank_bank_branch_id_fkey FOREIGN KEY (bank_branch_id) REFERENCES company.bank_branch(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7577 (class 2606 OID 36480)
-- Name: company_bank company_bank_bank_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_bank
    ADD CONSTRAINT company_bank_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES company.bank(id) ON DELETE CASCADE;


--
-- TOC entry 7578 (class 2606 OID 36485)
-- Name: company_bank company_bank_payment_profile_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_bank
    ADD CONSTRAINT company_bank_payment_profile_id_fkey FOREIGN KEY (payment_profile_id) REFERENCES company.payment_profile(id) ON DELETE CASCADE;


--
-- TOC entry 7579 (class 2606 OID 36490)
-- Name: company_bank company_bank_payment_type_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_bank
    ADD CONSTRAINT company_bank_payment_type_id_fkey FOREIGN KEY (payment_type_id) REFERENCES company.payment_type(id) ON DELETE CASCADE;


--
-- TOC entry 7784 (class 2606 OID 78187)
-- Name: sg_community_fund_setup company_comm_fund_setup; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_community_fund_setup
    ADD CONSTRAINT company_comm_fund_setup FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7785 (class 2606 OID 78215)
-- Name: sg_donation_setup company_donation; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT company_donation FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7862 (class 2606 OID 91972)
-- Name: sg_donation_setup_link company_donation_link; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup_link
    ADD CONSTRAINT company_donation_link FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7806 (class 2606 OID 80519)
-- Name: sg_union_setup company_union; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT company_union FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7868 (class 2606 OID 92109)
-- Name: sg_union_setup_link company_union_setup_link; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup_link
    ADD CONSTRAINT company_union_setup_link FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7582 (class 2606 OID 36581)
-- Name: cpf_account cpf_account_company_bank_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.cpf_account
    ADD CONSTRAINT cpf_account_company_bank_id_fkey FOREIGN KEY (company_bank_id) REFERENCES company.company_bank(id) ON DELETE CASCADE;


--
-- TOC entry 7750 (class 2606 OID 74097)
-- Name: customize_rest_day_grouping customize_rest_day_grouping_employment_classification_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.customize_rest_day_grouping
    ADD CONSTRAINT customize_rest_day_grouping_employment_classification_id_fkey FOREIGN KEY (employment_classification_id) REFERENCES company.code_setup(id) ON DELETE CASCADE;


--
-- TOC entry 7751 (class 2606 OID 73846)
-- Name: customize_rest_day_grouping customize_rest_day_grouping_rd_ceiling_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.customize_rest_day_grouping
    ADD CONSTRAINT customize_rest_day_grouping_rd_ceiling_id_fkey FOREIGN KEY (rd_ceiling_id) REFERENCES company.lk_rd_ceiling(id);


--
-- TOC entry 7583 (class 2606 OID 48834)
-- Name: documents documents_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.documents
    ADD CONSTRAINT documents_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7584 (class 2606 OID 36621)
-- Name: documents documents_document_category_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.documents
    ADD CONSTRAINT documents_document_category_id_fkey FOREIGN KEY (document_category_id) REFERENCES company.document_category(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 7786 (class 2606 OID 78220)
-- Name: sg_donation_setup donation_backpay_allowance_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_backpay_allowance_fkey FOREIGN KEY (backpay_allowance_id) REFERENCES company.allowance_deduction(id) ON DELETE SET NULL;


--
-- TOC entry 7787 (class 2606 OID 78225)
-- Name: sg_donation_setup donation_benefit_in_kind_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_benefit_in_kind_fkey FOREIGN KEY (benefit_in_kind_id) REFERENCES company.allowance_deduction_benefit_in_kind(id) ON DELETE CASCADE;


--
-- TOC entry 7788 (class 2606 OID 78230)
-- Name: sg_donation_setup donation_bonus_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_bonus_type_fkey FOREIGN KEY (bonus_type_id) REFERENCES company.allowance_deduction_bonus_type(id) ON DELETE SET NULL;


--
-- TOC entry 7789 (class 2606 OID 78235)
-- Name: sg_donation_setup donation_category; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_category FOREIGN KEY (category_id) REFERENCES company.lk_donation_category(id) ON DELETE CASCADE;


--
-- TOC entry 7790 (class 2606 OID 78240)
-- Name: sg_donation_setup donation_cpf_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_cpf_fkey FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7791 (class 2606 OID 78245)
-- Name: sg_donation_setup donation_gross_wage_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_gross_wage_fkey FOREIGN KEY (gross_wage_id) REFERENCES company.allowance_deduction_gross_wage(id) ON DELETE SET NULL;


--
-- TOC entry 7792 (class 2606 OID 78250)
-- Name: sg_donation_setup donation_grp_formula_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_grp_formula_fkey FOREIGN KEY (grp_formula_id) REFERENCES company.allowance_deduction_grp_formula(id) ON DELETE SET NULL;


--
-- TOC entry 7793 (class 2606 OID 78255)
-- Name: sg_donation_setup donation_tax_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_tax_fkey FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id) ON DELETE CASCADE;


--
-- TOC entry 7794 (class 2606 OID 78260)
-- Name: sg_donation_setup donation_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_type_fkey FOREIGN KEY (type_id) REFERENCES company.allowance_deduction_type(id) ON DELETE CASCADE;


--
-- TOC entry 7795 (class 2606 OID 78265)
-- Name: sg_donation_setup donation_unit_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup
    ADD CONSTRAINT donation_unit_fkey FOREIGN KEY (unit_id) REFERENCES company.allowance_deduction_unit(id) ON DELETE SET NULL;


--
-- TOC entry 7571 (class 2606 OID 36382)
-- Name: company fk_area; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company
    ADD CONSTRAINT fk_area FOREIGN KEY (area_id) REFERENCES company.area(id);


--
-- TOC entry 7658 (class 2606 OID 110743)
-- Name: code_setup fk_code_setup_country; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fk_code_setup_country FOREIGN KEY (country_id, company_id) REFERENCES company.code_setup(id, company_id) ON DELETE RESTRICT;


--
-- TOC entry 7580 (class 2606 OID 48844)
-- Name: company_contact_info fk_company; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_contact_info
    ADD CONSTRAINT fk_company FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7651 (class 2606 OID 56380)
-- Name: company_employment_setting fk_company_employment; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_employment_setting
    ADD CONSTRAINT fk_company_employment FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7581 (class 2606 OID 36538)
-- Name: company_layout fk_company_layout; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_layout
    ADD CONSTRAINT fk_company_layout FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7572 (class 2606 OID 48862)
-- Name: company fk_company_status; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company
    ADD CONSTRAINT fk_company_status FOREIGN KEY (company_status_id) REFERENCES company.company_status(id) NOT VALID;


--
-- TOC entry 7610 (class 2606 OID 48889)
-- Name: my_tax_requirement fk_company_tax_my; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.my_tax_requirement
    ADD CONSTRAINT fk_company_tax_my FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7570 (class 2606 OID 48839)
-- Name: country_state fk_country; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.country_state
    ADD CONSTRAINT fk_country FOREIGN KEY (country_id) REFERENCES company.country(id) NOT VALID;


--
-- TOC entry 7974 (class 2606 OID 112755)
-- Name: document_favourite fk_document_favourite_document; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.document_favourite
    ADD CONSTRAINT fk_document_favourite_document FOREIGN KEY (document_id) REFERENCES company.documents(id) ON DELETE CASCADE;


--
-- TOC entry 7975 (class 2606 OID 112750)
-- Name: document_favourite fk_document_favourite_user; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.document_favourite
    ADD CONSTRAINT fk_document_favourite_user FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7585 (class 2606 OID 36642)
-- Name: id_provident_fund fk_id_pf_bank; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_provident_fund
    ADD CONSTRAINT fk_id_pf_bank FOREIGN KEY (company_bank_id) REFERENCES company.company_bank(id) ON DELETE CASCADE;


--
-- TOC entry 7586 (class 2606 OID 36695)
-- Name: id_tax_requirement fk_income_tax_wage; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_tax_requirement
    ADD CONSTRAINT fk_income_tax_wage FOREIGN KEY (income_tax_wage_id) REFERENCES company.id_wage_type(id);


--
-- TOC entry 7573 (class 2606 OID 36392)
-- Name: company fk_industry; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company
    ADD CONSTRAINT fk_industry FOREIGN KEY (industry_id) REFERENCES company.industry(id);


--
-- TOC entry 7569 (class 2606 OID 36230)
-- Name: industry fk_industry_group; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.industry
    ADD CONSTRAINT fk_industry_group FOREIGN KEY (industry_group_id) REFERENCES company.industry_group(id) ON DELETE CASCADE;


--
-- TOC entry 7587 (class 2606 OID 36700)
-- Name: id_tax_requirement fk_jkk_wage; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_tax_requirement
    ADD CONSTRAINT fk_jkk_wage FOREIGN KEY (jkk_jht_jkm_wage_id) REFERENCES company.id_wage_type(id);


--
-- TOC entry 7588 (class 2606 OID 36705)
-- Name: id_tax_requirement fk_job_wage; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_tax_requirement
    ADD CONSTRAINT fk_job_wage FOREIGN KEY (job_title_wage_id) REFERENCES company.id_wage_type(id);


--
-- TOC entry 7956 (class 2606 OID 105296)
-- Name: module_lock_configuration_module fk_module_lock_configuration_module_config; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.module_lock_configuration_module
    ADD CONSTRAINT fk_module_lock_configuration_module_config FOREIGN KEY (module_lock_configuration_id) REFERENCES company.module_lock_configuration(id) ON DELETE CASCADE;


--
-- TOC entry 7591 (class 2606 OID 36787)
-- Name: my_provident_fund fk_my_pf_bank; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.my_provident_fund
    ADD CONSTRAINT fk_my_pf_bank FOREIGN KEY (company_bank_id) REFERENCES company.company_bank(id) ON DELETE CASCADE;


--
-- TOC entry 7652 (class 2606 OID 55891)
-- Name: company_employment_setting fk_notice_period_type; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_employment_setting
    ADD CONSTRAINT fk_notice_period_type FOREIGN KEY (notice_period_type_id) REFERENCES company.period_type(id) NOT VALID;


--
-- TOC entry 7593 (class 2606 OID 48879)
-- Name: sg_tax_requirement fk_organization_types; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_tax_requirement
    ADD CONSTRAINT fk_organization_types FOREIGN KEY (organization_types_id) REFERENCES company.organization_types(id) NOT VALID;


--
-- TOC entry 7701 (class 2606 OID 63716)
-- Name: ot_rate_code fk_ot_rate_code_cpf; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_rate_code
    ADD CONSTRAINT fk_ot_rate_code_cpf FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7702 (class 2606 OID 63721)
-- Name: ot_rate_code fk_ot_rate_code_tax; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_rate_code
    ADD CONSTRAINT fk_ot_rate_code_tax FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id) ON DELETE CASCADE;


--
-- TOC entry 7574 (class 2606 OID 36397)
-- Name: company fk_parent_company; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company
    ADD CONSTRAINT fk_parent_company FOREIGN KEY (parent_company_id) REFERENCES company.company(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 7594 (class 2606 OID 48884)
-- Name: sg_tax_requirement fk_payer_types; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_tax_requirement
    ADD CONSTRAINT fk_payer_types FOREIGN KEY (payer_types_id) REFERENCES company.payer_types(id) NOT VALID;


--
-- TOC entry 7653 (class 2606 OID 55896)
-- Name: company_employment_setting fk_probation_period_type; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_employment_setting
    ADD CONSTRAINT fk_probation_period_type FOREIGN KEY (probation_period_type_id) REFERENCES company.period_type(id) NOT VALID;


--
-- TOC entry 7863 (class 2606 OID 97294)
-- Name: sg_donation_setup_link fk_src_company_id; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_donation_setup_link
    ADD CONSTRAINT fk_src_company_id FOREIGN KEY (src_company_id) REFERENCES company.company(id);


--
-- TOC entry 7869 (class 2606 OID 97299)
-- Name: sg_union_setup_link fk_src_company_id; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup_link
    ADD CONSTRAINT fk_src_company_id FOREIGN KEY (src_company_id) REFERENCES company.company(id);


--
-- TOC entry 7589 (class 2606 OID 36710)
-- Name: id_tax_requirement fk_tax_company; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_tax_requirement
    ADD CONSTRAINT fk_tax_company FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7590 (class 2606 OID 36715)
-- Name: id_tax_requirement fk_tax_refund; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.id_tax_requirement
    ADD CONSTRAINT fk_tax_refund FOREIGN KEY (tax_refund_calculation_id) REFERENCES company.id_tax_refund_calculation(id);


--
-- TOC entry 7714 (class 2606 OID 64897)
-- Name: absent_code fkey_absent_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.absent_code
    ADD CONSTRAINT fkey_absent_code FOREIGN KEY (absent_id) REFERENCES company.company_absent(id) ON DELETE CASCADE;


--
-- TOC entry 7715 (class 2606 OID 64902)
-- Name: absent_code fkey_absent_code_cpf; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.absent_code
    ADD CONSTRAINT fkey_absent_code_cpf FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7920 (class 2606 OID 95665)
-- Name: company_asset fkey_asset_currency_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_asset
    ADD CONSTRAINT fkey_asset_currency_code FOREIGN KEY (currency_code_id, currency_code_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7926 (class 2606 OID 97815)
-- Name: asset_management_log fkey_asset_log; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.asset_management_log
    ADD CONSTRAINT fkey_asset_log FOREIGN KEY (asset_id) REFERENCES company.company_asset(id) ON DELETE CASCADE;


--
-- TOC entry 7921 (class 2606 OID 95670)
-- Name: company_asset fkey_asset_status; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_asset
    ADD CONSTRAINT fkey_asset_status FOREIGN KEY (asset_status_id) REFERENCES company.lk_asset_status(id);


--
-- TOC entry 7922 (class 2606 OID 95675)
-- Name: company_asset fkey_asset_type; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_asset
    ADD CONSTRAINT fkey_asset_type FOREIGN KEY (asset_type_id, asset_type_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7657 (class 2606 OID 60998)
-- Name: code_setup_type fkey_code_category; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup_type
    ADD CONSTRAINT fkey_code_category FOREIGN KEY (code_setup_category_id) REFERENCES company.code_setup_category(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7659 (class 2606 OID 61025)
-- Name: code_setup fkey_code_occupation_category; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fkey_code_occupation_category FOREIGN KEY (occupation_category_id) REFERENCES company.occupation_category(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7660 (class 2606 OID 61015)
-- Name: code_setup fkey_code_occupation_group; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fkey_code_occupation_group FOREIGN KEY (occupation_group_id) REFERENCES company.sg_occupation_group(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7661 (class 2606 OID 56887)
-- Name: code_setup fkey_code_relation; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fkey_code_relation FOREIGN KEY (relation_type_id) REFERENCES company.relation_type(id) ON DELETE SET NULL;


--
-- TOC entry 7662 (class 2606 OID 56892)
-- Name: code_setup fkey_code_type; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fkey_code_type FOREIGN KEY (code_setup_type_id) REFERENCES company.code_setup_type(id);


--
-- TOC entry 7700 (class 2606 OID 63593)
-- Name: sg_oed_map_code fkey_code_type; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_oed_map_code
    ADD CONSTRAINT fkey_code_type FOREIGN KEY (code_setup_type_id) REFERENCES company.code_setup_type(id) ON DELETE CASCADE;


--
-- TOC entry 7650 (class 2606 OID 56385)
-- Name: company_organization_structure fkey_comp_org_struct; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_organization_structure
    ADD CONSTRAINT fkey_comp_org_struct FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7713 (class 2606 OID 64880)
-- Name: company_absent fkey_company_absent; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_absent
    ADD CONSTRAINT fkey_company_absent FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7923 (class 2606 OID 95680)
-- Name: company_asset fkey_company_asset; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_asset
    ADD CONSTRAINT fkey_company_asset FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7663 (class 2606 OID 56897)
-- Name: code_setup fkey_company_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fkey_company_code FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7867 (class 2606 OID 92137)
-- Name: sg_cpf_profile fkey_company_cpf_profile; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_cpf_profile
    ADD CONSTRAINT fkey_company_cpf_profile FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7685 (class 2606 OID 62406)
-- Name: company_rate_formula fkey_company_formula; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_rate_formula
    ADD CONSTRAINT fkey_company_formula FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7732 (class 2606 OID 67430)
-- Name: company_nsp_setup fkey_company_nsp; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_nsp_setup
    ADD CONSTRAINT fkey_company_nsp FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7752 (class 2606 OID 73935)
-- Name: ot_capping_code fkey_company_ot_cap; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_capping_code
    ADD CONSTRAINT fkey_company_ot_cap FOREIGN KEY (company_ot_capping_id) REFERENCES company.company_ot_capping(id) ON DELETE CASCADE;


--
-- TOC entry 7739 (class 2606 OID 73660)
-- Name: company_ot_capping fkey_company_ot_capping; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_ot_capping
    ADD CONSTRAINT fkey_company_ot_capping FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7705 (class 2606 OID 64769)
-- Name: company_public_holiday fkey_company_public_holiday; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_public_holiday
    ADD CONSTRAINT fkey_company_public_holiday FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7691 (class 2606 OID 62688)
-- Name: company_rest_day fkey_company_rest_day; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_rest_day
    ADD CONSTRAINT fkey_company_rest_day FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7716 (class 2606 OID 64975)
-- Name: company_shift_setup fkey_company_shift; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_shift_setup
    ADD CONSTRAINT fkey_company_shift FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7737 (class 2606 OID 70275)
-- Name: work_code fkey_company_work_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.work_code
    ADD CONSTRAINT fkey_company_work_code FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7796 (class 2606 OID 92117)
-- Name: sg_cpf_setup fkey_cpf_profile; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_cpf_setup
    ADD CONSTRAINT fkey_cpf_profile FOREIGN KEY (cpf_profile_id) REFERENCES company.sg_cpf_profile(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7686 (class 2606 OID 62411)
-- Name: company_rate_formula fkey_formula_daily_rate; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_rate_formula
    ADD CONSTRAINT fkey_formula_daily_rate FOREIGN KEY (daily_rate_id) REFERENCES company.lk_daily_rate(id);


--
-- TOC entry 7664 (class 2606 OID 61020)
-- Name: code_setup fkey_highest_education_attained; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fkey_highest_education_attained FOREIGN KEY (highest_education_attained_id) REFERENCES company.sg_highest_education_attained(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7855 (class 2606 OID 92142)
-- Name: company_levy_management fkey_levy_area; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_levy_management
    ADD CONSTRAINT fkey_levy_area FOREIGN KEY (area_id) REFERENCES company.area(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7861 (class 2606 OID 90965)
-- Name: levy_management_pay_period fkey_levy_management_pay; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.levy_management_pay_period
    ADD CONSTRAINT fkey_levy_management_pay FOREIGN KEY (levy_management_id) REFERENCES company.company_levy_management(id) ON DELETE CASCADE;


--
-- TOC entry 7856 (class 2606 OID 92147)
-- Name: company_levy_management fkey_levy_method; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_levy_management
    ADD CONSTRAINT fkey_levy_method FOREIGN KEY (levy_method_id) REFERENCES company.lk_levy_method(id) NOT VALID;


--
-- TOC entry 7857 (class 2606 OID 90911)
-- Name: company_levy_management fkey_levy_quota; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_levy_management
    ADD CONSTRAINT fkey_levy_quota FOREIGN KEY (quota_id, quota_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7858 (class 2606 OID 90916)
-- Name: company_levy_management fkey_levy_sector; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_levy_management
    ADD CONSTRAINT fkey_levy_sector FOREIGN KEY (sector_id, sector_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7859 (class 2606 OID 90921)
-- Name: company_levy_management fkey_levy_tier; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_levy_management
    ADD CONSTRAINT fkey_levy_tier FOREIGN KEY (tier_id, tier_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7860 (class 2606 OID 90926)
-- Name: company_levy_management fkey_levy_work_pass; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_levy_management
    ADD CONSTRAINT fkey_levy_work_pass FOREIGN KEY (work_pass_id, work_pass_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7927 (class 2606 OID 97820)
-- Name: asset_management_log fkey_log_action; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.asset_management_log
    ADD CONSTRAINT fkey_log_action FOREIGN KEY (log_action_id) REFERENCES company.lk_asset_management_log_action(id);


--
-- TOC entry 7733 (class 2606 OID 74086)
-- Name: company_nsp_setup fkey_nsp_deduction_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_nsp_setup
    ADD CONSTRAINT fkey_nsp_deduction_code FOREIGN KEY (nsp_deduction_code_id) REFERENCES company.allowance_deduction(id) ON DELETE CASCADE;


--
-- TOC entry 7734 (class 2606 OID 67440)
-- Name: company_nsp_setup fkey_nsp_formula; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_nsp_setup
    ADD CONSTRAINT fkey_nsp_formula FOREIGN KEY (nsp_formula_id) REFERENCES company.lk_nsp_formula(id) ON DELETE CASCADE;


--
-- TOC entry 7665 (class 2606 OID 63598)
-- Name: code_setup fkey_oed_map_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.code_setup
    ADD CONSTRAINT fkey_oed_map_code FOREIGN KEY (oed_map_code_id) REFERENCES company.sg_oed_map_code(id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 7753 (class 2606 OID 73940)
-- Name: ot_capping_code fkey_ot_cap_code_setup; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_capping_code
    ADD CONSTRAINT fkey_ot_cap_code_setup FOREIGN KEY (code_id) REFERENCES company.code_setup(id) ON DELETE CASCADE;


--
-- TOC entry 7754 (class 2606 OID 73945)
-- Name: ot_capping_code fkey_ot_cap_method; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_capping_code
    ADD CONSTRAINT fkey_ot_cap_method FOREIGN KEY (ot_ceiling_method_id) REFERENCES company.lk_ot_ceiling_method(id) ON DELETE CASCADE;


--
-- TOC entry 7740 (class 2606 OID 73665)
-- Name: company_ot_capping fkey_ot_capping_type_cap; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_ot_capping
    ADD CONSTRAINT fkey_ot_capping_type_cap FOREIGN KEY (ot_ceiling_type_id) REFERENCES company.lk_ot_ceiling_type(id) ON DELETE CASCADE;


--
-- TOC entry 7703 (class 2606 OID 63726)
-- Name: ot_rate_code fkey_ot_rate; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_rate_code
    ADD CONSTRAINT fkey_ot_rate FOREIGN KEY (ot_rate_id) REFERENCES company.company_ot_rate(id) ON DELETE CASCADE;


--
-- TOC entry 7704 (class 2606 OID 63731)
-- Name: ot_rate_code fkey_ot_rate_status; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.ot_rate_code
    ADD CONSTRAINT fkey_ot_rate_status FOREIGN KEY (ot_rate_status_id) REFERENCES company.lk_rest_day_status(id) ON DELETE CASCADE;


--
-- TOC entry 7708 (class 2606 OID 64800)
-- Name: public_holiday_code fkey_ph_code_cpf; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday_code
    ADD CONSTRAINT fkey_ph_code_cpf FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7709 (class 2606 OID 64805)
-- Name: public_holiday_code fkey_ph_code_rest_rate; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday_code
    ADD CONSTRAINT fkey_ph_code_rest_rate FOREIGN KEY (public_holiday_rate_id) REFERENCES company.lk_rest_day_rate(id) ON DELETE CASCADE;


--
-- TOC entry 7710 (class 2606 OID 64810)
-- Name: public_holiday_code fkey_ph_code_status; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday_code
    ADD CONSTRAINT fkey_ph_code_status FOREIGN KEY (public_holiday_status_id) REFERENCES company.lk_rest_day_status(id) ON DELETE CASCADE;


--
-- TOC entry 7711 (class 2606 OID 64815)
-- Name: public_holiday_code fkey_ph_code_tax; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday_code
    ADD CONSTRAINT fkey_ph_code_tax FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id) ON DELETE CASCADE;


--
-- TOC entry 7706 (class 2606 OID 64774)
-- Name: company_public_holiday fkey_ph_daily_rate; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_public_holiday
    ADD CONSTRAINT fkey_ph_daily_rate FOREIGN KEY (daily_rate_id) REFERENCES company.lk_daily_rate(id) ON DELETE CASCADE;


--
-- TOC entry 7707 (class 2606 OID 64779)
-- Name: company_public_holiday fkey_ph_rounding; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_public_holiday
    ADD CONSTRAINT fkey_ph_rounding FOREIGN KEY (rounding_method_id) REFERENCES company.lk_rounding_method(id) ON DELETE CASCADE;


--
-- TOC entry 7712 (class 2606 OID 64820)
-- Name: public_holiday_code fkey_public_holiday_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday_code
    ADD CONSTRAINT fkey_public_holiday_code FOREIGN KEY (public_holiday_id) REFERENCES company.company_public_holiday(id) ON DELETE CASCADE;


--
-- TOC entry 7695 (class 2606 OID 62932)
-- Name: rest_day_code fkey_rest_day_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_code
    ADD CONSTRAINT fkey_rest_day_code FOREIGN KEY (rest_day_id) REFERENCES company.company_rest_day(id) ON DELETE CASCADE;


--
-- TOC entry 7696 (class 2606 OID 62937)
-- Name: rest_day_code fkey_rest_day_cpf; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_code
    ADD CONSTRAINT fkey_rest_day_cpf FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7692 (class 2606 OID 62693)
-- Name: company_rest_day fkey_rest_day_daily; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_rest_day
    ADD CONSTRAINT fkey_rest_day_daily FOREIGN KEY (daily_rate_id) REFERENCES company.lk_daily_rate(id) ON DELETE SET DEFAULT;


--
-- TOC entry 7697 (class 2606 OID 62942)
-- Name: rest_day_code fkey_rest_day_rate; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_code
    ADD CONSTRAINT fkey_rest_day_rate FOREIGN KEY (rest_day_rate_id) REFERENCES company.lk_rest_day_rate(id) ON DELETE CASCADE;


--
-- TOC entry 7693 (class 2606 OID 62698)
-- Name: company_rest_day fkey_rest_day_rounding; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_rest_day
    ADD CONSTRAINT fkey_rest_day_rounding FOREIGN KEY (rounding_method_id) REFERENCES company.lk_rounding_method(id) ON DELETE SET DEFAULT;


--
-- TOC entry 7698 (class 2606 OID 62947)
-- Name: rest_day_code fkey_rest_day_status; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_code
    ADD CONSTRAINT fkey_rest_day_status FOREIGN KEY (rest_day_status_id) REFERENCES company.lk_rest_day_status(id);


--
-- TOC entry 7699 (class 2606 OID 62952)
-- Name: rest_day_code fkey_rest_day_tax; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_code
    ADD CONSTRAINT fkey_rest_day_tax FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id) ON DELETE CASCADE;


--
-- TOC entry 7954 (class 2606 OID 101492)
-- Name: query_builder_rule_users fkey_rule; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.query_builder_rule_users
    ADD CONSTRAINT fkey_rule FOREIGN KEY (rule_id) REFERENCES company.query_builder_rules(id) ON DELETE CASCADE;


--
-- TOC entry 7952 (class 2606 OID 101440)
-- Name: query_builder_rules fkey_rule_company; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.query_builder_rules
    ADD CONSTRAINT fkey_rule_company FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7953 (class 2606 OID 101477)
-- Name: query_builder_rules fkey_rule_status; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.query_builder_rules
    ADD CONSTRAINT fkey_rule_status FOREIGN KEY (status_id) REFERENCES company.lk_status(id) ON DELETE SET NULL;


--
-- TOC entry 7949 (class 2606 OID 100441)
-- Name: salary_scale_setup fkey_salary_scale_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.salary_scale_setup
    ADD CONSTRAINT fkey_salary_scale_code FOREIGN KEY (salary_scale_id, salary_scale_type_id) REFERENCES company.code_setup(id, code_setup_type_id) ON DELETE CASCADE;


--
-- TOC entry 7717 (class 2606 OID 64980)
-- Name: company_shift_setup fkey_shift_average_month; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_shift_setup
    ADD CONSTRAINT fkey_shift_average_month FOREIGN KEY (average_shift_month_id) REFERENCES company.lk_average_shift_month(id) ON DELETE CASCADE;


--
-- TOC entry 7719 (class 2606 OID 65056)
-- Name: shift_setup_code fkey_shift_cpf; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.shift_setup_code
    ADD CONSTRAINT fkey_shift_cpf FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7718 (class 2606 OID 64985)
-- Name: company_shift_setup fkey_shift_rounfing; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.company_shift_setup
    ADD CONSTRAINT fkey_shift_rounfing FOREIGN KEY (rounding_method_id) REFERENCES company.lk_rounding_method(id) ON DELETE CASCADE;


--
-- TOC entry 7720 (class 2606 OID 65061)
-- Name: shift_setup_code fkey_shift_setup_code; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.shift_setup_code
    ADD CONSTRAINT fkey_shift_setup_code FOREIGN KEY (shift_setup_id) REFERENCES company.company_shift_setup(id) ON DELETE CASCADE;


--
-- TOC entry 7721 (class 2606 OID 65066)
-- Name: shift_setup_code fkey_shift_tax; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.shift_setup_code
    ADD CONSTRAINT fkey_shift_tax FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id) ON DELETE CASCADE;


--
-- TOC entry 7722 (class 2606 OID 65071)
-- Name: shift_setup_code fkey_shift_unit; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.shift_setup_code
    ADD CONSTRAINT fkey_shift_unit FOREIGN KEY (unit_id) REFERENCES company.lk_duration_unit(id) ON DELETE CASCADE;


--
-- TOC entry 7955 (class 2606 OID 101497)
-- Name: query_builder_rule_users fkey_status; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.query_builder_rule_users
    ADD CONSTRAINT fkey_status FOREIGN KEY (status_id) REFERENCES company.lk_status(id) ON DELETE RESTRICT;


--
-- TOC entry 7764 (class 2606 OID 75674)
-- Name: formula_setup_settings formula_setup_settings_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.formula_setup_settings
    ADD CONSTRAINT formula_setup_settings_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7765 (class 2606 OID 75684)
-- Name: formula_setup_settings formula_setup_settings_formula_setup_method_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.formula_setup_settings
    ADD CONSTRAINT formula_setup_settings_formula_setup_method_id_fkey FOREIGN KEY (formula_setup_method_id) REFERENCES company.lk_formula_setup_method(id);


--
-- TOC entry 7766 (class 2606 OID 75679)
-- Name: formula_setup_settings formula_setup_settings_prorate_salary_formula_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.formula_setup_settings
    ADD CONSTRAINT formula_setup_settings_prorate_salary_formula_id_fkey FOREIGN KEY (prorate_salary_formula_id) REFERENCES company.lk_prorate_salary_formula(id);


--
-- TOC entry 7762 (class 2606 OID 75605)
-- Name: leave_financial_period leave_financial_period_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.leave_financial_period
    ADD CONSTRAINT leave_financial_period_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7677 (class 2606 OID 64714)
-- Name: npl_configuration npl_configuration_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.npl_configuration
    ADD CONSTRAINT npl_configuration_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7678 (class 2606 OID 62209)
-- Name: npl_configuration npl_configuration_daily_rate_formula_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.npl_configuration
    ADD CONSTRAINT npl_configuration_daily_rate_formula_id_fkey FOREIGN KEY (daily_rate_formula_id) REFERENCES company.lk_daily_rate(id);


--
-- TOC entry 7679 (class 2606 OID 62214)
-- Name: npl_configuration npl_configuration_rounding_method_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.npl_configuration
    ADD CONSTRAINT npl_configuration_rounding_method_id_fkey FOREIGN KEY (rounding_method_id) REFERENCES company.lk_rounding_method(id);


--
-- TOC entry 7680 (class 2606 OID 64719)
-- Name: npl_rate npl_rate_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.npl_rate
    ADD CONSTRAINT npl_rate_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7681 (class 2606 OID 62238)
-- Name: npl_rate npl_rate_cpf_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.npl_rate
    ADD CONSTRAINT npl_rate_cpf_fkey FOREIGN KEY (cpf) REFERENCES company.allowance_deduction_cpf(id);


--
-- TOC entry 7772 (class 2606 OID 78059)
-- Name: pay_group_calendar pay_group_calendar_pay_group_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_calendar
    ADD CONSTRAINT pay_group_calendar_pay_group_id_fkey FOREIGN KEY (pay_group_id) REFERENCES company.pay_group(id) ON DELETE CASCADE;


--
-- TOC entry 7767 (class 2606 OID 77991)
-- Name: pay_group pay_group_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group
    ADD CONSTRAINT pay_group_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7768 (class 2606 OID 77996)
-- Name: pay_group pay_group_daily_rate_by_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group
    ADD CONSTRAINT pay_group_daily_rate_by_fkey FOREIGN KEY (daily_rate_by) REFERENCES company.lk_daily_rate(id);


--
-- TOC entry 7771 (class 2606 OID 78038)
-- Name: pay_group_global_weekly_settings pay_group_global_weekly_settings_pay_group_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_global_weekly_settings
    ADD CONSTRAINT pay_group_global_weekly_settings_pay_group_id_fkey FOREIGN KEY (pay_group_id) REFERENCES company.pay_group(id) ON DELETE CASCADE;


--
-- TOC entry 7769 (class 2606 OID 78001)
-- Name: pay_group pay_group_npl_rate_formula_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group
    ADD CONSTRAINT pay_group_npl_rate_formula_fkey FOREIGN KEY (npl_rate_formula) REFERENCES company.lk_daily_rate(id);


--
-- TOC entry 7770 (class 2606 OID 78006)
-- Name: pay_group pay_group_ot_hour_formula_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group
    ADD CONSTRAINT pay_group_ot_hour_formula_fkey FOREIGN KEY (ot_hour_formula) REFERENCES company.lk_ot_rate_formula(id);


--
-- TOC entry 7773 (class 2606 OID 78080)
-- Name: pay_group_weekly pay_group_weekly_pay_group_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.pay_group_weekly
    ADD CONSTRAINT pay_group_weekly_pay_group_id_fkey FOREIGN KEY (pay_group_id) REFERENCES company.pay_group(id) ON DELETE CASCADE;


--
-- TOC entry 7575 (class 2606 OID 36446)
-- Name: payment_profile payment_profile_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payment_profile
    ADD CONSTRAINT payment_profile_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7761 (class 2606 OID 75585)
-- Name: payroll_financial_period payroll_financial_period_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.payroll_financial_period
    ADD CONSTRAINT payroll_financial_period_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7741 (class 2606 OID 73705)
-- Name: prorate_allowance_configuration prorate_allowance_configuration_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_configuration
    ADD CONSTRAINT prorate_allowance_configuration_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7742 (class 2606 OID 73710)
-- Name: prorate_allowance_configuration prorate_allowance_configuration_prorate_payitem_formula_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_configuration
    ADD CONSTRAINT prorate_allowance_configuration_prorate_payitem_formula_id_fkey FOREIGN KEY (prorate_payitem_formula_id) REFERENCES company.lk_prorate_formula(id);


--
-- TOC entry 7743 (class 2606 OID 73730)
-- Name: prorate_allowance_deduction_assignment prorate_allowance_deduction_a_company_allowance_deduction__fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_assignment
    ADD CONSTRAINT prorate_allowance_deduction_a_company_allowance_deduction__fkey FOREIGN KEY (company_allowance_deduction_id) REFERENCES company.allowance_deduction(id) ON DELETE CASCADE;


--
-- TOC entry 7744 (class 2606 OID 73740)
-- Name: prorate_allowance_deduction_assignment prorate_allowance_deduction_ass_prorate_payitem_formula_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_assignment
    ADD CONSTRAINT prorate_allowance_deduction_ass_prorate_payitem_formula_id_fkey FOREIGN KEY (prorate_payitem_formula_id) REFERENCES company.lk_prorate_formula(id);


--
-- TOC entry 7745 (class 2606 OID 73735)
-- Name: prorate_allowance_deduction_assignment prorate_allowance_deduction_assignment_deduction_code_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_assignment
    ADD CONSTRAINT prorate_allowance_deduction_assignment_deduction_code_id_fkey FOREIGN KEY (deduction_code_id) REFERENCES company.allowance_deduction(id) ON DELETE CASCADE;


--
-- TOC entry 7746 (class 2606 OID 73768)
-- Name: prorate_allowance_deduction_leave_assignment prorate_allowance_deduction_l_company_allowance_deduction__fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_leave_assignment
    ADD CONSTRAINT prorate_allowance_deduction_l_company_allowance_deduction__fkey FOREIGN KEY (company_allowance_deduction_id) REFERENCES company.allowance_deduction(id) ON DELETE CASCADE;


--
-- TOC entry 7747 (class 2606 OID 73773)
-- Name: prorate_allowance_deduction_leave_assignment prorate_allowance_deduction_leave_assignment_leave_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.prorate_allowance_deduction_leave_assignment
    ADD CONSTRAINT prorate_allowance_deduction_leave_assignment_leave_type_fkey FOREIGN KEY (leave_type) REFERENCES leave.lk_leave_type(id);


--
-- TOC entry 7738 (class 2606 OID 72389)
-- Name: public_holiday public_holiday_type_id; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.public_holiday
    ADD CONSTRAINT public_holiday_type_id FOREIGN KEY (public_holiday_type_id) REFERENCES company.public_holiday_type(id) ON DELETE CASCADE;


--
-- TOC entry 7748 (class 2606 OID 74091)
-- Name: rest_day_capping_settings rest_day_capping_settings_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_capping_settings
    ADD CONSTRAINT rest_day_capping_settings_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7749 (class 2606 OID 73821)
-- Name: rest_day_capping_settings rest_day_capping_settings_rd_ceiling_method_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.rest_day_capping_settings
    ADD CONSTRAINT rest_day_capping_settings_rd_ceiling_method_id_fkey FOREIGN KEY (rd_ceiling_method_id) REFERENCES company.lk_rd_ceiling_method(id);


--
-- TOC entry 7592 (class 2606 OID 36830)
-- Name: sg_provident_fund sg_provident_fund_company_bank_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_provident_fund
    ADD CONSTRAINT sg_provident_fund_company_bank_id_fkey FOREIGN KEY (company_bank_id) REFERENCES company.company_bank(id) ON DELETE CASCADE;


--
-- TOC entry 7595 (class 2606 OID 36860)
-- Name: sg_tax_requirement sg_tax_requirement_detail_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_tax_requirement
    ADD CONSTRAINT sg_tax_requirement_detail_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7807 (class 2606 OID 80524)
-- Name: sg_union_setup union_backpay_allowance_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_backpay_allowance_fkey FOREIGN KEY (backpay_allowance_id) REFERENCES company.allowance_deduction(id) ON DELETE SET NULL;


--
-- TOC entry 7808 (class 2606 OID 80529)
-- Name: sg_union_setup union_benefit_in_kind_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_benefit_in_kind_fkey FOREIGN KEY (benefit_in_kind_id) REFERENCES company.allowance_deduction_benefit_in_kind(id) ON DELETE CASCADE;


--
-- TOC entry 7759 (class 2606 OID 75562)
-- Name: union_bonus union_bonus_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_bonus
    ADD CONSTRAINT union_bonus_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7756 (class 2606 OID 75525)
-- Name: union_bonus_type union_bonus_type_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_bonus_type
    ADD CONSTRAINT union_bonus_type_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7809 (class 2606 OID 80534)
-- Name: sg_union_setup union_bonus_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_bonus_type_fkey FOREIGN KEY (bonus_type_id) REFERENCES company.allowance_deduction_bonus_type(id) ON DELETE SET NULL;


--
-- TOC entry 7760 (class 2606 OID 75567)
-- Name: union_bonus union_bonus_union_type_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_bonus
    ADD CONSTRAINT union_bonus_union_type_id_fkey FOREIGN KEY (union_type_id) REFERENCES company.union_type(id) ON DELETE CASCADE;


--
-- TOC entry 7810 (class 2606 OID 80539)
-- Name: sg_union_setup union_category; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_category FOREIGN KEY (category_id) REFERENCES company.lk_union_category(id) ON DELETE CASCADE;


--
-- TOC entry 7757 (class 2606 OID 75541)
-- Name: union union_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company."union"
    ADD CONSTRAINT union_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7811 (class 2606 OID 80544)
-- Name: sg_union_setup union_cpf_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_cpf_fkey FOREIGN KEY (cpf_id) REFERENCES company.allowance_deduction_cpf(id) ON DELETE CASCADE;


--
-- TOC entry 7812 (class 2606 OID 80549)
-- Name: sg_union_setup union_gross_wage_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_gross_wage_fkey FOREIGN KEY (gross_wage_id) REFERENCES company.allowance_deduction_gross_wage(id) ON DELETE SET NULL;


--
-- TOC entry 7813 (class 2606 OID 80554)
-- Name: sg_union_setup union_grp_formula_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_grp_formula_fkey FOREIGN KEY (grp_formula_id) REFERENCES company.allowance_deduction_grp_formula(id) ON DELETE SET NULL;


--
-- TOC entry 7814 (class 2606 OID 80559)
-- Name: sg_union_setup union_tax_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_tax_fkey FOREIGN KEY (tax_id) REFERENCES company.allowance_deduction_tax(id) ON DELETE CASCADE;


--
-- TOC entry 7755 (class 2606 OID 75507)
-- Name: union_type union_type_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.union_type
    ADD CONSTRAINT union_type_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7815 (class 2606 OID 80564)
-- Name: sg_union_setup union_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_type_fkey FOREIGN KEY (type_id) REFERENCES company.allowance_deduction_type(id) ON DELETE CASCADE;


--
-- TOC entry 7758 (class 2606 OID 75546)
-- Name: union union_union_type_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company."union"
    ADD CONSTRAINT union_union_type_id_fkey FOREIGN KEY (union_type_id) REFERENCES company.union_type(id) ON DELETE CASCADE;


--
-- TOC entry 7816 (class 2606 OID 80569)
-- Name: sg_union_setup union_unit_fkey; Type: FK CONSTRAINT; Schema: company; Owner: timesadmin
--

ALTER TABLE ONLY company.sg_union_setup
    ADD CONSTRAINT union_unit_fkey FOREIGN KEY (unit_id) REFERENCES company.allowance_deduction_unit(id) ON DELETE SET NULL;


--
-- TOC entry 7928 (class 2606 OID 98123)
-- Name: career_progression career_progression_appraisal_grade_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_appraisal_grade_fkey FOREIGN KEY (appraisal_grade_id, appraisal_grade_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7929 (class 2606 OID 98128)
-- Name: career_progression career_progression_branch_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_branch_fkey FOREIGN KEY (branch_id, branch_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7930 (class 2606 OID 98133)
-- Name: career_progression career_progression_career_progression_code_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_career_progression_code_fkey FOREIGN KEY (career_progression_code_id, career_progression_code_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7931 (class 2606 OID 98138)
-- Name: career_progression career_progression_category_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_category_fkey FOREIGN KEY (category_id, category_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7932 (class 2606 OID 98143)
-- Name: career_progression career_progression_classification_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_classification_fkey FOREIGN KEY (classification_id, classification_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7933 (class 2606 OID 98148)
-- Name: career_progression career_progression_contract_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7934 (class 2606 OID 98153)
-- Name: career_progression career_progression_cost_centre_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_cost_centre_fkey FOREIGN KEY (cost_centre_id, cost_centre_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7935 (class 2606 OID 98158)
-- Name: career_progression career_progression_department_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_department_fkey FOREIGN KEY (department_id, department_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7936 (class 2606 OID 98163)
-- Name: career_progression career_progression_division_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_division_fkey FOREIGN KEY (division_id, division_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7937 (class 2606 OID 98168)
-- Name: career_progression career_progression_employment_classification_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_employment_classification_fkey FOREIGN KEY (employment_classification_id, employment_classification_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7938 (class 2606 OID 98173)
-- Name: career_progression career_progression_job_grade_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_job_grade_fkey FOREIGN KEY (job_grade_id, job_grade_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7939 (class 2606 OID 98178)
-- Name: career_progression career_progression_job_level_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_job_level_fkey FOREIGN KEY (job_level_id, job_level_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7940 (class 2606 OID 98183)
-- Name: career_progression career_progression_location_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_location_fkey FOREIGN KEY (location_id, location_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7941 (class 2606 OID 98188)
-- Name: career_progression career_progression_occupation_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_occupation_fkey FOREIGN KEY (occupation_id, occupation_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7942 (class 2606 OID 98193)
-- Name: career_progression career_progression_salary_scale_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_salary_scale_fkey FOREIGN KEY (salary_scale_id, salary_scale_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7943 (class 2606 OID 98198)
-- Name: career_progression career_progression_section_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_section_fkey FOREIGN KEY (section_id, section_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7944 (class 2606 OID 98203)
-- Name: career_progression career_progression_team_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_team_fkey FOREIGN KEY (team_id, team_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7945 (class 2606 OID 98208)
-- Name: career_progression career_progression_unit_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.career_progression
    ADD CONSTRAINT career_progression_unit_fkey FOREIGN KEY (unit_id, unit_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7825 (class 2606 OID 89281)
-- Name: epm_ns_record epm_ns_record_nature_of_service_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_nature_of_service_id_fkey FOREIGN KEY (nature_of_service_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7826 (class 2606 OID 89276)
-- Name: epm_ns_record epm_ns_record_ns_status_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_ns_status_id_fkey FOREIGN KEY (ns_status_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7827 (class 2606 OID 89291)
-- Name: epm_ns_record epm_ns_record_rank_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_rank_id_fkey FOREIGN KEY (rank_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7828 (class 2606 OID 89296)
-- Name: epm_ns_record epm_ns_record_rating_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7829 (class 2606 OID 89271)
-- Name: epm_ns_record epm_ns_record_regulatory_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_regulatory_id_fkey FOREIGN KEY (regulatory_id) REFERENCES employee.user_regulatory(id);


--
-- TOC entry 7830 (class 2606 OID 89316)
-- Name: epm_ns_record epm_ns_record_res_rank_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_res_rank_id_fkey FOREIGN KEY (res_rank_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7831 (class 2606 OID 89301)
-- Name: epm_ns_record epm_ns_record_res_status_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_res_status_id_fkey FOREIGN KEY (res_status_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7832 (class 2606 OID 89311)
-- Name: epm_ns_record epm_ns_record_res_type_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_res_type_id_fkey FOREIGN KEY (res_type_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7833 (class 2606 OID 89321)
-- Name: epm_ns_record epm_ns_record_res_unit_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_res_unit_id_fkey FOREIGN KEY (res_unit_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7834 (class 2606 OID 89306)
-- Name: epm_ns_record epm_ns_record_res_vocation_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_res_vocation_id_fkey FOREIGN KEY (res_vocation_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7835 (class 2606 OID 89286)
-- Name: epm_ns_record epm_ns_record_vocation_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_ns_record
    ADD CONSTRAINT epm_ns_record_vocation_id_fkey FOREIGN KEY (vocation_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7870 (class 2606 OID 92199)
-- Name: epm_union_info epm_union_info_regulatory_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_union_info
    ADD CONSTRAINT epm_union_info_regulatory_id_fkey FOREIGN KEY (regulatory_id) REFERENCES employee.user_regulatory(id) ON DELETE CASCADE;


--
-- TOC entry 7871 (class 2606 OID 92204)
-- Name: epm_union_info epm_union_info_union_worker_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_union_info
    ADD CONSTRAINT epm_union_info_union_worker_id_fkey FOREIGN KEY (union_worker_id) REFERENCES employee.lk_union_worker(id);


--
-- TOC entry 7821 (class 2606 OID 89242)
-- Name: epm_work_pass_records epm_work_pass_records_pass_status_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_work_pass_records
    ADD CONSTRAINT epm_work_pass_records_pass_status_id_fkey FOREIGN KEY (pass_status_id) REFERENCES employee.lk_pass_status(id);


--
-- TOC entry 7822 (class 2606 OID 89232)
-- Name: epm_work_pass_records epm_work_pass_records_regulatory_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_work_pass_records
    ADD CONSTRAINT epm_work_pass_records_regulatory_id_fkey FOREIGN KEY (regulatory_id) REFERENCES employee.user_regulatory(id) ON DELETE CASCADE;


--
-- TOC entry 7905 (class 2606 OID 95490)
-- Name: family_info family_info_dependent_status_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.family_info
    ADD CONSTRAINT family_info_dependent_status_id_fkey FOREIGN KEY (dependent_status_id) REFERENCES employee.lk_dependent_status(id);


--
-- TOC entry 7906 (class 2606 OID 95485)
-- Name: family_info family_info_marital_status_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.family_info
    ADD CONSTRAINT family_info_marital_status_id_fkey FOREIGN KEY (marital_status_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7907 (class 2606 OID 95480)
-- Name: family_info family_info_nationality_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.family_info
    ADD CONSTRAINT family_info_nationality_id_fkey FOREIGN KEY (nationality_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7908 (class 2606 OID 95475)
-- Name: family_info family_info_relationship_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.family_info
    ADD CONSTRAINT family_info_relationship_id_fkey FOREIGN KEY (relationship_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7909 (class 2606 OID 95465)
-- Name: family_info family_info_user_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.family_info
    ADD CONSTRAINT family_info_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7853 (class 2606 OID 89758)
-- Name: address_usage_type fk_address_usage; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.address_usage_type
    ADD CONSTRAINT fk_address_usage FOREIGN KEY (address_id) REFERENCES employee.user_company_address(id) ON DELETE CASCADE;


--
-- TOC entry 7854 (class 2606 OID 89763)
-- Name: address_usage_type fk_usage_address; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.address_usage_type
    ADD CONSTRAINT fk_usage_address FOREIGN KEY (usage_tag_id) REFERENCES employee.lk_usage_tag(id) ON DELETE CASCADE;


--
-- TOC entry 7847 (class 2606 OID 89685)
-- Name: user_company_address fk_user_address; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_address
    ADD CONSTRAINT fk_user_address FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7848 (class 2606 OID 89695)
-- Name: user_company_address fk_user_company_address_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_address
    ADD CONSTRAINT fk_user_company_address_type FOREIGN KEY (address_type_id) REFERENCES security.lk_address_type(id) ON DELETE CASCADE;


--
-- TOC entry 7894 (class 2606 OID 93869)
-- Name: contract_allowance_deduction fkey_ad_amount_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_allowance_deduction
    ADD CONSTRAINT fkey_ad_amount_type FOREIGN KEY (amount_type_id) REFERENCES employee.lk_amount_type(id);


--
-- TOC entry 7895 (class 2606 OID 93874)
-- Name: contract_allowance_deduction fkey_ad_currency_code; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_allowance_deduction
    ADD CONSTRAINT fkey_ad_currency_code FOREIGN KEY (currency_code_id, currency_code_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7896 (class 2606 OID 93879)
-- Name: contract_allowance_deduction fkey_ad_pay_code; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_allowance_deduction
    ADD CONSTRAINT fkey_ad_pay_code FOREIGN KEY (pay_code_id) REFERENCES company.allowance_deduction(id);


--
-- TOC entry 7897 (class 2606 OID 93884)
-- Name: contract_allowance_deduction fkey_ad_payroll_cycle; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_allowance_deduction
    ADD CONSTRAINT fkey_ad_payroll_cycle FOREIGN KEY (payroll_cycle_id) REFERENCES payroll.lk_payroll_cycle(id);


--
-- TOC entry 7898 (class 2606 OID 93889)
-- Name: contract_allowance_deduction fkey_ad_recurring_method; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_allowance_deduction
    ADD CONSTRAINT fkey_ad_recurring_method FOREIGN KEY (recurring_method_id) REFERENCES employee.lk_recurring_method(id);


--
-- TOC entry 7924 (class 2606 OID 95721)
-- Name: user_company_asset fkey_company_user; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_asset
    ADD CONSTRAINT fkey_company_user FOREIGN KEY (user_id, company_id) REFERENCES security.user_company(user_id, company_id) ON DELETE CASCADE;


--
-- TOC entry 7899 (class 2606 OID 93894)
-- Name: contract_allowance_deduction fkey_contract_allowance_deduction; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_allowance_deduction
    ADD CONSTRAINT fkey_contract_allowance_deduction FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7838 (class 2606 OID 89582)
-- Name: user_company_contract fkey_contract_currency_code; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_currency_code FOREIGN KEY (currency_code_id, currency_code_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7864 (class 2606 OID 92017)
-- Name: contract_donations fkey_contract_donation; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_donations
    ADD CONSTRAINT fkey_contract_donation FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7852 (class 2606 OID 89742)
-- Name: contract_hr_note fkey_contract_hr_note; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_hr_note
    ADD CONSTRAINT fkey_contract_hr_note FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7839 (class 2606 OID 89587)
-- Name: user_company_contract fkey_contract_id_provident_fuund; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_id_provident_fuund FOREIGN KEY (id_provident_fund_id) REFERENCES company.id_provident_fund(id) ON DELETE SET NULL;


--
-- TOC entry 7840 (class 2606 OID 89592)
-- Name: user_company_contract fkey_contract_my_provident_fund; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_my_provident_fund FOREIGN KEY (my_provident_fund_id) REFERENCES company.my_provident_fund(id) ON DELETE SET NULL;


--
-- TOC entry 7841 (class 2606 OID 89597)
-- Name: user_company_contract fkey_contract_payment_profile; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_payment_profile FOREIGN KEY (payment_profile_id) REFERENCES company.payment_profile(id);


--
-- TOC entry 7842 (class 2606 OID 89602)
-- Name: user_company_contract fkey_contract_probation_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_probation_type FOREIGN KEY (probation_period_type_id) REFERENCES company.period_type(id) ON DELETE SET NULL;


--
-- TOC entry 7849 (class 2606 OID 89716)
-- Name: contract_resignation fkey_contract_resignation; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_resignation
    ADD CONSTRAINT fkey_contract_resignation FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7900 (class 2606 OID 93911)
-- Name: contract_scheme fkey_contract_scheme; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_scheme
    ADD CONSTRAINT fkey_contract_scheme FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7901 (class 2606 OID 93916)
-- Name: contract_scheme fkey_contract_scheme_code; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_scheme
    ADD CONSTRAINT fkey_contract_scheme_code FOREIGN KEY (scheme_code_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7902 (class 2606 OID 93921)
-- Name: contract_scheme fkey_contract_scheme_public_holiday_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_scheme
    ADD CONSTRAINT fkey_contract_scheme_public_holiday_type FOREIGN KEY (public_holiday_type_id) REFERENCES company.public_holiday_type(id);


--
-- TOC entry 7843 (class 2606 OID 89607)
-- Name: user_company_contract fkey_contract_service_grade; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_service_grade FOREIGN KEY (service_grade_id) REFERENCES employee.lk_service_grade(id) ON DELETE SET NULL;


--
-- TOC entry 7882 (class 2606 OID 93705)
-- Name: contract_service_point fkey_contract_service_point; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_service_point
    ADD CONSTRAINT fkey_contract_service_point FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7844 (class 2606 OID 89612)
-- Name: user_company_contract fkey_contract_sg_provident_fund; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_sg_provident_fund FOREIGN KEY (sg_provident_fund_id) REFERENCES company.sg_provident_fund(id) ON DELETE SET NULL;


--
-- TOC entry 7903 (class 2606 OID 93950)
-- Name: contract_stop_payment fkey_contract_stop_payment; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_stop_payment
    ADD CONSTRAINT fkey_contract_stop_payment FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7904 (class 2606 OID 93955)
-- Name: contract_stop_payment fkey_contract_stop_payment_indicator; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_stop_payment
    ADD CONSTRAINT fkey_contract_stop_payment_indicator FOREIGN KEY (stop_payment_indicator_id) REFERENCES employee.lk_stop_payment_indicator(id);


--
-- TOC entry 7845 (class 2606 OID 89617)
-- Name: user_company_contract fkey_contract_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_contract_type FOREIGN KEY (contract_type_id, contract_type_code_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7865 (class 2606 OID 92022)
-- Name: contract_donations fkey_donation_period; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_donations
    ADD CONSTRAINT fkey_donation_period FOREIGN KEY (period_id) REFERENCES employee.lk_donation_period(id);


--
-- TOC entry 7866 (class 2606 OID 92027)
-- Name: contract_donations fkey_donation_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_donations
    ADD CONSTRAINT fkey_donation_type FOREIGN KEY (donation_type_id) REFERENCES company.sg_donation_setup(id);


--
-- TOC entry 7925 (class 2606 OID 95726)
-- Name: user_company_asset fkey_epm_asset; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_asset
    ADD CONSTRAINT fkey_epm_asset FOREIGN KEY (asset_id) REFERENCES company.company_asset(id) ON DELETE CASCADE;


--
-- TOC entry 7823 (class 2606 OID 92165)
-- Name: epm_work_pass_records fkey_epm_work_pass_type_; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_work_pass_records
    ADD CONSTRAINT fkey_epm_work_pass_type_ FOREIGN KEY (work_pass_id, work_pass_type_id) REFERENCES company.code_setup(id, code_setup_type_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7850 (class 2606 OID 89721)
-- Name: contract_resignation fkey_notice_period_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_resignation
    ADD CONSTRAINT fkey_notice_period_type FOREIGN KEY (notice_period_type_id) REFERENCES company.period_type(id);


--
-- TOC entry 7886 (class 2606 OID 93784)
-- Name: contract_pay_setting fkey_pay_setting_contract; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT fkey_pay_setting_contract FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE CASCADE;


--
-- TOC entry 7887 (class 2606 OID 93789)
-- Name: contract_pay_setting fkey_pay_setting_daily_rate; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT fkey_pay_setting_daily_rate FOREIGN KEY (daily_rate_formula_id) REFERENCES company.lk_daily_rate(id);


--
-- TOC entry 7888 (class 2606 OID 93794)
-- Name: contract_pay_setting fkey_pay_setting_festival; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT fkey_pay_setting_festival FOREIGN KEY (festival_advance_id) REFERENCES employee.lk_festival_advance(id) ON DELETE SET NULL;


--
-- TOC entry 7889 (class 2606 OID 93799)
-- Name: contract_pay_setting fkey_pay_setting_hourly_rate; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT fkey_pay_setting_hourly_rate FOREIGN KEY (hourly_rate_formula_id) REFERENCES company.lk_daily_rate(id);


--
-- TOC entry 7890 (class 2606 OID 93804)
-- Name: contract_pay_setting fkey_pay_setting_pay_group; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT fkey_pay_setting_pay_group FOREIGN KEY (pay_group_id) REFERENCES company.pay_group(id);


--
-- TOC entry 7891 (class 2606 OID 93809)
-- Name: contract_pay_setting fkey_pay_setting_pay_type; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT fkey_pay_setting_pay_type FOREIGN KEY (pay_type_id, pay_type_code_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7893 (class 2606 OID 93833)
-- Name: pay_setting_work_calendar fkey_pay_setting_work_calendar; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.pay_setting_work_calendar
    ADD CONSTRAINT fkey_pay_setting_work_calendar FOREIGN KEY (pay_setting_id) REFERENCES employee.contract_pay_setting(id) ON DELETE CASCADE;


--
-- TOC entry 7892 (class 2606 OID 93814)
-- Name: contract_pay_setting fkey_pay_setting_work_code; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_pay_setting
    ADD CONSTRAINT fkey_pay_setting_work_code FOREIGN KEY (working_code_id) REFERENCES company.work_code(id) ON DELETE SET NULL;


--
-- TOC entry 7851 (class 2606 OID 89726)
-- Name: contract_resignation fkey_resignation_reason; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_resignation
    ADD CONSTRAINT fkey_resignation_reason FOREIGN KEY (reason_id, reason_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7883 (class 2606 OID 93710)
-- Name: contract_service_point fkey_service_point_code; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_service_point
    ADD CONSTRAINT fkey_service_point_code FOREIGN KEY (allowance_deduction_id) REFERENCES company.allowance_deduction(id);


--
-- TOC entry 7885 (class 2606 OID 93731)
-- Name: service_point_payslip_message fkey_service_point_message; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.service_point_payslip_message
    ADD CONSTRAINT fkey_service_point_message FOREIGN KEY (service_point_id) REFERENCES employee.contract_service_point(id) ON DELETE CASCADE;


--
-- TOC entry 7884 (class 2606 OID 93715)
-- Name: contract_service_point fkey_service_point_period; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.contract_service_point
    ADD CONSTRAINT fkey_service_point_period FOREIGN KEY (period_id) REFERENCES employee.lk_service_point_period(id);


--
-- TOC entry 7846 (class 2606 OID 89622)
-- Name: user_company_contract fkey_user_company_contract; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_contract
    ADD CONSTRAINT fkey_user_company_contract FOREIGN KEY (user_id, company_id) REFERENCES security.user_company(user_id, company_id) ON DELETE CASCADE;


--
-- TOC entry 7919 (class 2606 OID 95586)
-- Name: user_company_setting fkey_user_company_setting; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_setting
    ADD CONSTRAINT fkey_user_company_setting FOREIGN KEY (user_id, company_id) REFERENCES security.user_company(user_id, company_id) ON DELETE CASCADE;


--
-- TOC entry 7824 (class 2606 OID 100420)
-- Name: epm_work_pass_records fkey_work_pass_levy; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.epm_work_pass_records
    ADD CONSTRAINT fkey_work_pass_levy FOREIGN KEY (levy_management_id) REFERENCES company.company_levy_management(id) ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 7872 (class 2606 OID 93575)
-- Name: payment_profile payment_profile_bank_type_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_bank_type_id_fkey FOREIGN KEY (bank_type_id) REFERENCES company.bank_type(id);


--
-- TOC entry 7873 (class 2606 OID 105217)
-- Name: payment_profile payment_profile_contract_company_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_contract_company_fkey FOREIGN KEY (contract_id, user_id, company_id) REFERENCES employee.user_company_contract(id, user_id, company_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 7874 (class 2606 OID 93585)
-- Name: payment_profile payment_profile_overflow_bank_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_overflow_bank_id_fkey FOREIGN KEY (overflow_bank_id) REFERENCES company.bank(id);


--
-- TOC entry 7875 (class 2606 OID 93590)
-- Name: payment_profile payment_profile_overflow_branch_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_overflow_branch_id_fkey FOREIGN KEY (overflow_branch_id) REFERENCES company.bank_branch(id);


--
-- TOC entry 7876 (class 2606 OID 93580)
-- Name: payment_profile payment_profile_overflow_payment_mode_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_overflow_payment_mode_id_fkey FOREIGN KEY (overflow_payment_mode_id) REFERENCES company.payment_mode(id);


--
-- TOC entry 7877 (class 2606 OID 93565)
-- Name: payment_profile payment_profile_user_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_profile
    ADD CONSTRAINT payment_profile_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7878 (class 2606 OID 93626)
-- Name: payment_split payment_split_bank_branch_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_split
    ADD CONSTRAINT payment_split_bank_branch_id_fkey FOREIGN KEY (bank_branch_id) REFERENCES company.bank_branch(id);


--
-- TOC entry 7879 (class 2606 OID 93621)
-- Name: payment_split payment_split_bank_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_split
    ADD CONSTRAINT payment_split_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES company.bank(id);


--
-- TOC entry 7880 (class 2606 OID 93616)
-- Name: payment_split payment_split_payment_mode_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_split
    ADD CONSTRAINT payment_split_payment_mode_id_fkey FOREIGN KEY (payment_mode_id) REFERENCES company.payment_mode(id);


--
-- TOC entry 7881 (class 2606 OID 93611)
-- Name: payment_split payment_split_payment_profile_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.payment_split
    ADD CONSTRAINT payment_split_payment_profile_id_fkey FOREIGN KEY (payment_profile_id) REFERENCES employee.payment_profile(id) ON DELETE CASCADE;


--
-- TOC entry 7910 (class 2606 OID 101371)
-- Name: user_company_education user_company_education_cert_issuer_country_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_cert_issuer_country_id_fkey FOREIGN KEY (country_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7911 (class 2606 OID 101366)
-- Name: user_company_education user_company_education_country_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_country_id_fkey FOREIGN KEY (country_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7912 (class 2606 OID 95528)
-- Name: user_company_education user_company_education_education_level_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_education_level_id_fkey FOREIGN KEY (education_level_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7913 (class 2606 OID 95533)
-- Name: user_company_education user_company_education_grade_scale_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_grade_scale_id_fkey FOREIGN KEY (grade_scale_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7914 (class 2606 OID 95538)
-- Name: user_company_education user_company_education_institution_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7915 (class 2606 OID 95543)
-- Name: user_company_education user_company_education_major_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_major_id_fkey FOREIGN KEY (major_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7916 (class 2606 OID 95548)
-- Name: user_company_education user_company_education_minor_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_minor_id_fkey FOREIGN KEY (minor_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7917 (class 2606 OID 95553)
-- Name: user_company_education user_company_education_provider_type_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_provider_type_id_fkey FOREIGN KEY (provider_type_id) REFERENCES company.code_setup(id);


--
-- TOC entry 7918 (class 2606 OID 105210)
-- Name: user_company_education user_company_education_user_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_company_education
    ADD CONSTRAINT user_company_education_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7946 (class 2606 OID 98232)
-- Name: user_regulatory_commfund_topup user_regulatory_commfund_topup_company_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_commfund_topup
    ADD CONSTRAINT user_regulatory_commfund_topup_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7947 (class 2606 OID 98237)
-- Name: user_regulatory_commfund_topup user_regulatory_commfund_topup_type_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_commfund_topup
    ADD CONSTRAINT user_regulatory_commfund_topup_type_id_fkey FOREIGN KEY (type_id) REFERENCES employee.lk_fund_topup_type(id) ON DELETE RESTRICT;


--
-- TOC entry 7948 (class 2606 OID 98242)
-- Name: user_regulatory_commfund_topup user_regulatory_commfund_topup_user_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_commfund_topup
    ADD CONSTRAINT user_regulatory_commfund_topup_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7818 (class 2606 OID 100425)
-- Name: user_regulatory user_regulatory_custom_cpf_profile_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory
    ADD CONSTRAINT user_regulatory_custom_cpf_profile_id_fkey FOREIGN KEY (custom_cpf_profile_id) REFERENCES company.sg_cpf_profile(id) ON DELETE RESTRICT;


--
-- TOC entry 7820 (class 2606 OID 89214)
-- Name: user_regulatory_spr user_regulatory_spr_regulatory_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory_spr
    ADD CONSTRAINT user_regulatory_spr_regulatory_id_fkey FOREIGN KEY (regulatory_id) REFERENCES employee.user_regulatory(id) ON DELETE CASCADE;


--
-- TOC entry 7819 (class 2606 OID 89193)
-- Name: user_regulatory user_regulatory_user_id_fkey; Type: FK CONSTRAINT; Schema: employee; Owner: timesadmin
--

ALTER TABLE ONLY employee.user_regulatory
    ADD CONSTRAINT user_regulatory_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id);


--
-- TOC entry 7957 (class 2606 OID 107101)
-- Name: pay_run fk_pay_run_cycle; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_run
    ADD CONSTRAINT fk_pay_run_cycle FOREIGN KEY (pay_cycle_id) REFERENCES payroll.lk_payroll_cycle(id) ON DELETE CASCADE;


--
-- TOC entry 7687 (class 2606 OID 62487)
-- Name: encashment_policy fkey_company_encashment; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.encashment_policy
    ADD CONSTRAINT fkey_company_encashment FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7735 (class 2606 OID 70220)
-- Name: mso fkey_company_mso; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.mso
    ADD CONSTRAINT fkey_company_mso FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7966 (class 2606 OID 108153)
-- Name: pay_period fkey_company_pay_period; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_period
    ADD CONSTRAINT fkey_company_pay_period FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7958 (class 2606 OID 107157)
-- Name: pay_record fkey_contract_pay_record; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_record
    ADD CONSTRAINT fkey_contract_pay_record FOREIGN KEY (contract_id) REFERENCES employee.user_company_contract(id) ON DELETE RESTRICT;


--
-- TOC entry 7968 (class 2606 OID 112011)
-- Name: pay_period_contribution fkey_employee_contribution; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_period_contribution
    ADD CONSTRAINT fkey_employee_contribution FOREIGN KEY (user_id, company_id) REFERENCES security.user_company(user_id, company_id) ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 7688 (class 2606 OID 62492)
-- Name: encashment_policy fkey_encash_deduct_code; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.encashment_policy
    ADD CONSTRAINT fkey_encash_deduct_code FOREIGN KEY (encashment_deduction_code_id) REFERENCES company.allowance_deduction(id) ON DELETE SET NULL;


--
-- TOC entry 7689 (class 2606 OID 62497)
-- Name: encashment_policy fkey_encashment_code; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.encashment_policy
    ADD CONSTRAINT fkey_encashment_code FOREIGN KEY (encashment_code_id) REFERENCES company.allowance_deduction(id) ON DELETE SET NULL;


--
-- TOC entry 7690 (class 2606 OID 62502)
-- Name: encashment_policy fkey_encashment_method; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.encashment_policy
    ADD CONSTRAINT fkey_encashment_method FOREIGN KEY (encashment_method_id) REFERENCES payroll.lk_encashment_method(id);


--
-- TOC entry 7736 (class 2606 OID 70225)
-- Name: mso fkey_mso_rounding; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.mso
    ADD CONSTRAINT fkey_mso_rounding FOREIGN KEY (rounding_formula_id) REFERENCES payroll.rounding_formula(id) ON DELETE SET DEFAULT;


--
-- TOC entry 7969 (class 2606 OID 110918)
-- Name: pay_period_contribution fkey_pay_period_contribution; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_period_contribution
    ADD CONSTRAINT fkey_pay_period_contribution FOREIGN KEY (pay_period_id) REFERENCES payroll.pay_period(id) ON DELETE CASCADE;


--
-- TOC entry 7967 (class 2606 OID 110717)
-- Name: pay_record_modification fkey_pay_record_modification; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_record_modification
    ADD CONSTRAINT fkey_pay_record_modification FOREIGN KEY (pay_record_id) REFERENCES payroll.pay_record(id) ON DELETE CASCADE;


--
-- TOC entry 7959 (class 2606 OID 108914)
-- Name: pay_record fkey_pay_record_status; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_record
    ADD CONSTRAINT fkey_pay_record_status FOREIGN KEY (status_id) REFERENCES payroll.lk_pay_run_status(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7960 (class 2606 OID 107165)
-- Name: pay_record fkey_pay_run_record; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_record
    ADD CONSTRAINT fkey_pay_run_record FOREIGN KEY (pay_run_id) REFERENCES payroll.pay_run(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7694 (class 2606 OID 62880)
-- Name: rounding_formula fkey_rounding_company; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.rounding_formula
    ADD CONSTRAINT fkey_rounding_company FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7961 (class 2606 OID 112006)
-- Name: pay_record fkey_user_record; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.pay_record
    ADD CONSTRAINT fkey_user_record FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 7682 (class 2606 OID 64724)
-- Name: mvc mvc_company_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.mvc
    ADD CONSTRAINT mvc_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7683 (class 2606 OID 62333)
-- Name: mvc mvc_mvc_method_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.mvc
    ADD CONSTRAINT mvc_mvc_method_id_fkey FOREIGN KEY (mvc_method_id) REFERENCES payroll.lk_mvc_method(id);


--
-- TOC entry 7684 (class 2606 OID 62338)
-- Name: mvc mvc_mvc_schema_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.mvc
    ADD CONSTRAINT mvc_mvc_schema_id_fkey FOREIGN KEY (mvc_schema_id) REFERENCES payroll.lk_mvc_scheme(id);


--
-- TOC entry 7666 (class 2606 OID 57656)
-- Name: sg_payroll_settings sg_payroll_settings_company_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: timesadmin
--

ALTER TABLE ONLY payroll.sg_payroll_settings
    ADD CONSTRAINT sg_payroll_settings_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7655 (class 2606 OID 56206)
-- Name: guided_onboarding_log fk_guided_onboarding_log_code; Type: FK CONSTRAINT; Schema: public; Owner: timesadmin
--

ALTER TABLE ONLY public.guided_onboarding_log
    ADD CONSTRAINT fk_guided_onboarding_log_code FOREIGN KEY (guided_onboarding_code) REFERENCES public.guided_onboarding(code);


--
-- TOC entry 7656 (class 2606 OID 56201)
-- Name: guided_onboarding_log fk_guided_onboarding_log_user; Type: FK CONSTRAINT; Schema: public; Owner: timesadmin
--

ALTER TABLE ONLY public.guided_onboarding_log
    ADD CONSTRAINT fk_guided_onboarding_log_user FOREIGN KEY (user_id) REFERENCES security."user"(id);


--
-- TOC entry 7643 (class 2606 OID 52305)
-- Name: access_rules access_rules_company_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.access_rules
    ADD CONSTRAINT access_rules_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7644 (class 2606 OID 52315)
-- Name: access_rules access_rules_parent_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.access_rules
    ADD CONSTRAINT access_rules_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES security.access_rules(id) ON DELETE CASCADE;


--
-- TOC entry 7645 (class 2606 OID 52310)
-- Name: access_rules access_rules_permission_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.access_rules
    ADD CONSTRAINT access_rules_permission_fkey FOREIGN KEY (permission) REFERENCES security.permission(code);


--
-- TOC entry 7646 (class 2606 OID 52300)
-- Name: access_rules access_rules_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.access_rules
    ADD CONSTRAINT access_rules_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7723 (class 2606 OID 65621)
-- Name: disabled_roles disabled_roles_disabled_role_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.disabled_roles
    ADD CONSTRAINT disabled_roles_disabled_role_id_fkey FOREIGN KEY (disabled_role_id) REFERENCES security.role(id);


--
-- TOC entry 7724 (class 2606 OID 65616)
-- Name: disabled_roles disabled_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.disabled_roles
    ADD CONSTRAINT disabled_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES security.role(id);


--
-- TOC entry 7629 (class 2606 OID 52171)
-- Name: feature feature_function_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature
    ADD CONSTRAINT feature_function_id_fkey FOREIGN KEY (function_id) REFERENCES security.function(id) ON DELETE CASCADE;


--
-- TOC entry 7631 (class 2606 OID 52202)
-- Name: feature_permission feature_permission_feature_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature_permission
    ADD CONSTRAINT feature_permission_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES security.feature(id) ON DELETE CASCADE;


--
-- TOC entry 7632 (class 2606 OID 52207)
-- Name: feature_permission feature_permission_permission_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.feature_permission
    ADD CONSTRAINT feature_permission_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES security.permission(id) ON DELETE CASCADE;


--
-- TOC entry 7630 (class 2606 OID 52184)
-- Name: field field_feature_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.field
    ADD CONSTRAINT field_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES security.feature(id) ON DELETE CASCADE;


--
-- TOC entry 7633 (class 2606 OID 52217)
-- Name: field_permission field_permission_field_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.field_permission
    ADD CONSTRAINT field_permission_field_id_fkey FOREIGN KEY (field_id) REFERENCES security.field(id) ON DELETE CASCADE;


--
-- TOC entry 7634 (class 2606 OID 52222)
-- Name: field_permission field_permission_permission_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.field_permission
    ADD CONSTRAINT field_permission_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES security.permission(id) ON DELETE CASCADE;


--
-- TOC entry 7647 (class 2606 OID 109011)
-- Name: access_rules fk_access_rules_role; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.access_rules
    ADD CONSTRAINT fk_access_rules_role FOREIGN KEY (role_id) REFERENCES security.role(id);


--
-- TOC entry 7797 (class 2606 OID 80038)
-- Name: user_identity fk_citizenship_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_citizenship_type FOREIGN KEY (citizenship_id, citizenship_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7798 (class 2606 OID 80018)
-- Name: user_identity fk_martial_status_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_martial_status_type FOREIGN KEY (martial_status_id, martial_status_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7799 (class 2606 OID 80033)
-- Name: user_identity fk_nationality_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_nationality_type FOREIGN KEY (nationality_id, nationality_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7800 (class 2606 OID 80043)
-- Name: user_identity fk_palace_of_issue_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_palace_of_issue_type FOREIGN KEY (place_of_issue_id, place_of_issue_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7801 (class 2606 OID 80013)
-- Name: user_identity fk_place_of_birth_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_place_of_birth_type FOREIGN KEY (place_of_birth_id, place_of_birth_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7802 (class 2606 OID 80023)
-- Name: user_identity fk_race_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_race_type FOREIGN KEY (race_id, race_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7803 (class 2606 OID 80028)
-- Name: user_identity fk_relegion_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_relegion_type FOREIGN KEY (religion_id, religion_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7804 (class 2606 OID 80008)
-- Name: user_identity fk_salutation_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT fk_salutation_type FOREIGN KEY (salutation_id, salutation_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7817 (class 2606 OID 84159)
-- Name: address_usage_type fk_usage_address; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.address_usage_type
    ADD CONSTRAINT fk_usage_address FOREIGN KEY (usage_tag_id) REFERENCES security.lk_usage_tag(id) ON DELETE CASCADE;


--
-- TOC entry 7635 (class 2606 OID 55770)
-- Name: user_company_role fk_user_role_status; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role
    ADD CONSTRAINT fk_user_role_status FOREIGN KEY (user_role_status_id) REFERENCES security.user_role_status(id);


--
-- TOC entry 7640 (class 2606 OID 55765)
-- Name: user_role fk_user_role_status; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_role
    ADD CONSTRAINT fk_user_role_status FOREIGN KEY (user_role_status_id) REFERENCES security.user_role_status(id);


--
-- TOC entry 7624 (class 2606 OID 56397)
-- Name: user fk_user_status; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security."user"
    ADD CONSTRAINT fk_user_status FOREIGN KEY (user_status_id) REFERENCES security.user_status(id);


--
-- TOC entry 7970 (class 2606 OID 110961)
-- Name: role_transfer_request fkey_from_role; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_transfer_request
    ADD CONSTRAINT fkey_from_role FOREIGN KEY (from_role_id) REFERENCES security.role(id) ON DELETE CASCADE;


--
-- TOC entry 7971 (class 2606 OID 110951)
-- Name: role_transfer_request fkey_from_user; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_transfer_request
    ADD CONSTRAINT fkey_from_user FOREIGN KEY (from_user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7836 (class 2606 OID 89478)
-- Name: contract_resignation fkey_notice_period_type; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.contract_resignation
    ADD CONSTRAINT fkey_notice_period_type FOREIGN KEY (notice_period_type_id) REFERENCES company.period_type(id);


--
-- TOC entry 7837 (class 2606 OID 89483)
-- Name: contract_resignation fkey_resignation_reason; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.contract_resignation
    ADD CONSTRAINT fkey_resignation_reason FOREIGN KEY (reason_id, reason_type_id) REFERENCES company.code_setup(id, code_setup_type_id);


--
-- TOC entry 7950 (class 2606 OID 100502)
-- Name: data_security_rules fkey_rule_company; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.data_security_rules
    ADD CONSTRAINT fkey_rule_company FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7951 (class 2606 OID 100507)
-- Name: data_security_rules fkey_rule_user; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.data_security_rules
    ADD CONSTRAINT fkey_rule_user FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7972 (class 2606 OID 110966)
-- Name: role_transfer_request fkey_to_role; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_transfer_request
    ADD CONSTRAINT fkey_to_role FOREIGN KEY (to_role_id) REFERENCES security.role(id) ON DELETE CASCADE;


--
-- TOC entry 7973 (class 2606 OID 110956)
-- Name: role_transfer_request fkey_to_user; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_transfer_request
    ADD CONSTRAINT fkey_to_user FOREIGN KEY (to_user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7627 (class 2606 OID 102511)
-- Name: function function_feature_group_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.function
    ADD CONSTRAINT function_feature_group_id_fkey FOREIGN KEY (feature_group_id) REFERENCES security.feature_group(id);


--
-- TOC entry 7628 (class 2606 OID 52143)
-- Name: function function_licensing_plan_module_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.function
    ADD CONSTRAINT function_licensing_plan_module_id_fkey FOREIGN KEY (licensing_plan_module_id) REFERENCES subscription.licensing_plan_module(id);


--
-- TOC entry 7728 (class 2606 OID 65674)
-- Name: function_permission function_permission_function_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.function_permission
    ADD CONSTRAINT function_permission_function_id_fkey FOREIGN KEY (function_id) REFERENCES security.function(id);


--
-- TOC entry 7729 (class 2606 OID 65679)
-- Name: function_permission function_permission_permission_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.function_permission
    ADD CONSTRAINT function_permission_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES security.permission(id);


--
-- TOC entry 7964 (class 2606 OID 107431)
-- Name: privacy_security_rule_employees privacy_security_rule_employees_rule_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.privacy_security_rule_employees
    ADD CONSTRAINT privacy_security_rule_employees_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES security.privacy_security_rules(id) ON DELETE CASCADE;


--
-- TOC entry 7965 (class 2606 OID 107436)
-- Name: privacy_security_rule_employees privacy_security_rule_employees_target_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.privacy_security_rule_employees
    ADD CONSTRAINT privacy_security_rule_employees_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7962 (class 2606 OID 107420)
-- Name: privacy_security_rules privacy_security_rules_company_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.privacy_security_rules
    ADD CONSTRAINT privacy_security_rules_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7963 (class 2606 OID 107415)
-- Name: privacy_security_rules privacy_security_rules_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.privacy_security_rules
    ADD CONSTRAINT privacy_security_rules_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7730 (class 2606 OID 66851)
-- Name: rate_limit_log rate_limit_log_code_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.rate_limit_log
    ADD CONSTRAINT rate_limit_log_code_fkey FOREIGN KEY (code) REFERENCES security.rate_limit_type(code) ON DELETE CASCADE;


--
-- TOC entry 7731 (class 2606 OID 66846)
-- Name: rate_limit_log rate_limit_log_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.rate_limit_log
    ADD CONSTRAINT rate_limit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7648 (class 2606 OID 52328)
-- Name: role_function role_function_function_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_function
    ADD CONSTRAINT role_function_function_id_fkey FOREIGN KEY (function_id) REFERENCES security.function(id) ON DELETE CASCADE;


--
-- TOC entry 7649 (class 2606 OID 52333)
-- Name: role_function role_function_role_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.role_function
    ADD CONSTRAINT role_function_role_id_fkey FOREIGN KEY (role_id) REFERENCES security.role(id) ON DELETE CASCADE;


--
-- TOC entry 7625 (class 2606 OID 52119)
-- Name: user_company user_company_company_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company
    ADD CONSTRAINT user_company_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7636 (class 2606 OID 52241)
-- Name: user_company_role user_company_role_company_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role
    ADD CONSTRAINT user_company_role_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id) ON DELETE CASCADE;


--
-- TOC entry 7725 (class 2606 OID 65661)
-- Name: user_company_role_function user_company_role_function_company_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role_function
    ADD CONSTRAINT user_company_role_function_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.company(id);


--
-- TOC entry 7726 (class 2606 OID 65666)
-- Name: user_company_role_function user_company_role_function_role_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role_function
    ADD CONSTRAINT user_company_role_function_role_id_fkey FOREIGN KEY (role_id) REFERENCES security.role(id);


--
-- TOC entry 7727 (class 2606 OID 65656)
-- Name: user_company_role_function user_company_role_function_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role_function
    ADD CONSTRAINT user_company_role_function_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id);


--
-- TOC entry 7637 (class 2606 OID 52246)
-- Name: user_company_role user_company_role_role_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role
    ADD CONSTRAINT user_company_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES security.role(id) ON DELETE CASCADE;


--
-- TOC entry 7638 (class 2606 OID 66858)
-- Name: user_company_role user_company_role_user_id_company_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role
    ADD CONSTRAINT user_company_role_user_id_company_id_fkey FOREIGN KEY (user_id, company_id) REFERENCES security.user_company(user_id, company_id) ON DELETE CASCADE;


--
-- TOC entry 7639 (class 2606 OID 52236)
-- Name: user_company_role user_company_role_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company_role
    ADD CONSTRAINT user_company_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7626 (class 2606 OID 52114)
-- Name: user_company user_company_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_company
    ADD CONSTRAINT user_company_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7805 (class 2606 OID 80001)
-- Name: user_identity user_identity_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_identity
    ADD CONSTRAINT user_identity_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7641 (class 2606 OID 52270)
-- Name: user_role user_role_role_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_role
    ADD CONSTRAINT user_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES security.role(id) ON DELETE CASCADE;


--
-- TOC entry 7642 (class 2606 OID 52265)
-- Name: user_role user_role_user_id_fkey; Type: FK CONSTRAINT; Schema: security; Owner: timesadmin
--

ALTER TABLE ONLY security.user_role
    ADD CONSTRAINT user_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES security."user"(id) ON DELETE CASCADE;


--
-- TOC entry 7622 (class 2606 OID 49183)
-- Name: cancellation_request cancellation_request_cancellation_reason_id_fkey; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_request
    ADD CONSTRAINT cancellation_request_cancellation_reason_id_fkey FOREIGN KEY (cancellation_reason_id) REFERENCES subscription.cancellation_reason(id);


--
-- TOC entry 7623 (class 2606 OID 49198)
-- Name: cancellation_request_documents cancellation_request_documents_cancellation_request_id_fkey; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.cancellation_request_documents
    ADD CONSTRAINT cancellation_request_documents_cancellation_request_id_fkey FOREIGN KEY (cancellation_request_id) REFERENCES subscription.cancellation_request(id);


--
-- TOC entry 7616 (class 2606 OID 49206)
-- Name: subscription_transaction fk_activity_type; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_transaction
    ADD CONSTRAINT fk_activity_type FOREIGN KEY (activity_type_id) REFERENCES subscription.activity_type(id);


--
-- TOC entry 7600 (class 2606 OID 49145)
-- Name: price_item fk_item; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.price_item
    ADD CONSTRAINT fk_item FOREIGN KEY (item_id) REFERENCES subscription.item(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7608 (class 2606 OID 49140)
-- Name: subscription_pricing fk_item; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_pricing
    ADD CONSTRAINT fk_item FOREIGN KEY (item_id) REFERENCES subscription.item(id) NOT VALID;


--
-- TOC entry 7620 (class 2606 OID 49135)
-- Name: subscription_usage fk_item; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_usage
    ADD CONSTRAINT fk_item FOREIGN KEY (item_id) REFERENCES subscription.item(id) NOT VALID;


--
-- TOC entry 7611 (class 2606 OID 49116)
-- Name: payment_frequency_discount fk_licensing_plan; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.payment_frequency_discount
    ADD CONSTRAINT fk_licensing_plan FOREIGN KEY (licensing_plan_id) REFERENCES subscription.licensing_plan(id) ON DELETE CASCADE;


--
-- TOC entry 7601 (class 2606 OID 49111)
-- Name: price_item fk_licensing_plan; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.price_item
    ADD CONSTRAINT fk_licensing_plan FOREIGN KEY (licensing_plan_id) REFERENCES subscription.licensing_plan(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7602 (class 2606 OID 49106)
-- Name: subscription fk_licensing_plan; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription
    ADD CONSTRAINT fk_licensing_plan FOREIGN KEY (licensing_plan_id) REFERENCES subscription.licensing_plan(id) NOT VALID;


--
-- TOC entry 7604 (class 2606 OID 49101)
-- Name: subscription_contract fk_licensing_plan; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_contract
    ADD CONSTRAINT fk_licensing_plan FOREIGN KEY (licensing_plan_id) REFERENCES subscription.licensing_plan(id) NOT VALID;


--
-- TOC entry 7613 (class 2606 OID 49086)
-- Name: order_detail fk_payment_frequency; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.order_detail
    ADD CONSTRAINT fk_payment_frequency FOREIGN KEY (payment_frequency_id) REFERENCES subscription.payment_frequency(id);


--
-- TOC entry 7606 (class 2606 OID 49076)
-- Name: subscription_contract_schedule fk_payment_frequency; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_contract_schedule
    ADD CONSTRAINT fk_payment_frequency FOREIGN KEY (payment_frequency_id) REFERENCES subscription.payment_frequency(id) NOT VALID;


--
-- TOC entry 7614 (class 2606 OID 46925)
-- Name: order_detail fk_payment_frequency_discount; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.order_detail
    ADD CONSTRAINT fk_payment_frequency_discount FOREIGN KEY (payment_frequency_discount_id) REFERENCES subscription.payment_frequency_discount(id);


--
-- TOC entry 7617 (class 2606 OID 49062)
-- Name: subscription_transaction fk_payment_status; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_transaction
    ADD CONSTRAINT fk_payment_status FOREIGN KEY (payment_status_id) REFERENCES subscription.payment_status(id);


--
-- TOC entry 7605 (class 2606 OID 49012)
-- Name: subscription_contract fk_subscription_contract; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_contract
    ADD CONSTRAINT fk_subscription_contract FOREIGN KEY (subscription_contract_id) REFERENCES subscription.subscription_contract(id) NOT VALID;


--
-- TOC entry 7607 (class 2606 OID 48995)
-- Name: subscription_contract_schedule fk_subscription_contract; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_contract_schedule
    ADD CONSTRAINT fk_subscription_contract FOREIGN KEY (subscription_contract_id) REFERENCES subscription.subscription_contract(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7609 (class 2606 OID 48990)
-- Name: subscription_pricing fk_subscription_contract; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_pricing
    ADD CONSTRAINT fk_subscription_contract FOREIGN KEY (subscription_contract_id) REFERENCES subscription.subscription_contract(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7618 (class 2606 OID 48985)
-- Name: subscription_transaction fk_subscription_contract; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_transaction
    ADD CONSTRAINT fk_subscription_contract FOREIGN KEY (subscription_contract_id) REFERENCES subscription.subscription_contract(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7603 (class 2606 OID 49035)
-- Name: subscription fk_subscription_status; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription
    ADD CONSTRAINT fk_subscription_status FOREIGN KEY (subscription_status_id) REFERENCES subscription.subscription_status(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7619 (class 2606 OID 48952)
-- Name: subscription_invoice fk_subscription_transaction; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_invoice
    ADD CONSTRAINT fk_subscription_transaction FOREIGN KEY (subscription_transaction_id) REFERENCES subscription.subscription_transaction(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7621 (class 2606 OID 48899)
-- Name: subscription_usage fk_transaction_usage; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_usage
    ADD CONSTRAINT fk_transaction_usage FOREIGN KEY (subscription_transaction_id) REFERENCES subscription.subscription_transaction(id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 7654 (class 2606 OID 55911)
-- Name: subscription_transaction_document fkey_sub_trx_doc; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.subscription_transaction_document
    ADD CONSTRAINT fkey_sub_trx_doc FOREIGN KEY (subscription_transaction_id) REFERENCES subscription.subscription_transaction(id) ON DELETE CASCADE;


--
-- TOC entry 7615 (class 2606 OID 49121)
-- Name: order_detail licensing_plan_fk; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.order_detail
    ADD CONSTRAINT licensing_plan_fk FOREIGN KEY (licensing_plan_id) REFERENCES subscription.licensing_plan(id) ON DELETE SET NULL;


--
-- TOC entry 7612 (class 2606 OID 49081)
-- Name: payment_frequency_discount payment_frequency_fk; Type: FK CONSTRAINT; Schema: subscription; Owner: timesadmin
--

ALTER TABLE ONLY subscription.payment_frequency_discount
    ADD CONSTRAINT payment_frequency_fk FOREIGN KEY (payment_frequency_id) REFERENCES subscription.payment_frequency(id);


--
-- TOC entry 8128 (class 0 OID 0)
-- Dependencies: 933
-- Name: FUNCTION pg_replication_origin_advance(text, pg_lsn); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_advance(text, pg_lsn) TO azure_pg_admin;


--
-- TOC entry 8129 (class 0 OID 0)
-- Dependencies: 952
-- Name: FUNCTION pg_replication_origin_create(text); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_create(text) TO azure_pg_admin;


--
-- TOC entry 8130 (class 0 OID 0)
-- Dependencies: 951
-- Name: FUNCTION pg_replication_origin_drop(text); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_drop(text) TO azure_pg_admin;


--
-- TOC entry 8131 (class 0 OID 0)
-- Dependencies: 944
-- Name: FUNCTION pg_replication_origin_oid(text); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_oid(text) TO azure_pg_admin;


--
-- TOC entry 8132 (class 0 OID 0)
-- Dependencies: 945
-- Name: FUNCTION pg_replication_origin_progress(text, boolean); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_progress(text, boolean) TO azure_pg_admin;


--
-- TOC entry 8133 (class 0 OID 0)
-- Dependencies: 946
-- Name: FUNCTION pg_replication_origin_session_is_setup(); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_session_is_setup() TO azure_pg_admin;


--
-- TOC entry 8134 (class 0 OID 0)
-- Dependencies: 947
-- Name: FUNCTION pg_replication_origin_session_progress(boolean); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_session_progress(boolean) TO azure_pg_admin;


--
-- TOC entry 8135 (class 0 OID 0)
-- Dependencies: 934
-- Name: FUNCTION pg_replication_origin_session_reset(); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_session_reset() TO azure_pg_admin;


--
-- TOC entry 8136 (class 0 OID 0)
-- Dependencies: 948
-- Name: FUNCTION pg_replication_origin_session_setup(text); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_session_setup(text) TO azure_pg_admin;


--
-- TOC entry 8137 (class 0 OID 0)
-- Dependencies: 949
-- Name: FUNCTION pg_replication_origin_xact_reset(); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_xact_reset() TO azure_pg_admin;


--
-- TOC entry 8138 (class 0 OID 0)
-- Dependencies: 950
-- Name: FUNCTION pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) TO azure_pg_admin;


--
-- TOC entry 8139 (class 0 OID 0)
-- Dependencies: 935
-- Name: FUNCTION pg_show_replication_origin_status(OUT local_id oid, OUT external_id text, OUT remote_lsn pg_lsn, OUT local_lsn pg_lsn); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_show_replication_origin_status(OUT local_id oid, OUT external_id text, OUT remote_lsn pg_lsn, OUT local_lsn pg_lsn) TO azure_pg_admin;


--
-- TOC entry 8140 (class 0 OID 0)
-- Dependencies: 931
-- Name: FUNCTION pg_stat_reset(); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_stat_reset() TO azure_pg_admin;


--
-- TOC entry 8141 (class 0 OID 0)
-- Dependencies: 932
-- Name: FUNCTION pg_stat_reset_shared(text); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_stat_reset_shared(text) TO azure_pg_admin;


--
-- TOC entry 8142 (class 0 OID 0)
-- Dependencies: 941
-- Name: FUNCTION pg_stat_reset_single_function_counters(oid); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_stat_reset_single_function_counters(oid) TO azure_pg_admin;


--
-- TOC entry 8143 (class 0 OID 0)
-- Dependencies: 940
-- Name: FUNCTION pg_stat_reset_single_table_counters(oid); Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT ALL ON FUNCTION pg_catalog.pg_stat_reset_single_table_counters(oid) TO azure_pg_admin;


--
-- TOC entry 8154 (class 0 OID 0)
-- Dependencies: 118
-- Name: COLUMN pg_config.name; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(name) ON TABLE pg_catalog.pg_config TO azure_pg_admin;


--
-- TOC entry 8155 (class 0 OID 0)
-- Dependencies: 118
-- Name: COLUMN pg_config.setting; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(setting) ON TABLE pg_catalog.pg_config TO azure_pg_admin;


--
-- TOC entry 8156 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.line_number; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(line_number) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8157 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.type; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(type) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8158 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.database; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(database) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8159 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.user_name; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(user_name) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8160 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.address; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(address) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8161 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.netmask; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(netmask) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8162 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.auth_method; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(auth_method) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8163 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.options; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(options) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8164 (class 0 OID 0)
-- Dependencies: 114
-- Name: COLUMN pg_hba_file_rules.error; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(error) ON TABLE pg_catalog.pg_hba_file_rules TO azure_pg_admin;


--
-- TOC entry 8165 (class 0 OID 0)
-- Dependencies: 164
-- Name: COLUMN pg_replication_origin_status.local_id; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(local_id) ON TABLE pg_catalog.pg_replication_origin_status TO azure_pg_admin;


--
-- TOC entry 8166 (class 0 OID 0)
-- Dependencies: 164
-- Name: COLUMN pg_replication_origin_status.external_id; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(external_id) ON TABLE pg_catalog.pg_replication_origin_status TO azure_pg_admin;


--
-- TOC entry 8167 (class 0 OID 0)
-- Dependencies: 164
-- Name: COLUMN pg_replication_origin_status.remote_lsn; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(remote_lsn) ON TABLE pg_catalog.pg_replication_origin_status TO azure_pg_admin;


--
-- TOC entry 8168 (class 0 OID 0)
-- Dependencies: 164
-- Name: COLUMN pg_replication_origin_status.local_lsn; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(local_lsn) ON TABLE pg_catalog.pg_replication_origin_status TO azure_pg_admin;


--
-- TOC entry 8169 (class 0 OID 0)
-- Dependencies: 119
-- Name: COLUMN pg_shmem_allocations.name; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(name) ON TABLE pg_catalog.pg_shmem_allocations TO azure_pg_admin;


--
-- TOC entry 8170 (class 0 OID 0)
-- Dependencies: 119
-- Name: COLUMN pg_shmem_allocations.off; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(off) ON TABLE pg_catalog.pg_shmem_allocations TO azure_pg_admin;


--
-- TOC entry 8171 (class 0 OID 0)
-- Dependencies: 119
-- Name: COLUMN pg_shmem_allocations.size; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(size) ON TABLE pg_catalog.pg_shmem_allocations TO azure_pg_admin;


--
-- TOC entry 8172 (class 0 OID 0)
-- Dependencies: 119
-- Name: COLUMN pg_shmem_allocations.allocated_size; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(allocated_size) ON TABLE pg_catalog.pg_shmem_allocations TO azure_pg_admin;


--
-- TOC entry 8173 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.starelid; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(starelid) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8174 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.staattnum; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(staattnum) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8175 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stainherit; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stainherit) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8176 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stanullfrac; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stanullfrac) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8177 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stawidth; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stawidth) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8178 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stadistinct; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stadistinct) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8179 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stakind1; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stakind1) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8180 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stakind2; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stakind2) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8181 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stakind3; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stakind3) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8182 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stakind4; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stakind4) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8183 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stakind5; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stakind5) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8184 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.staop1; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(staop1) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8185 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.staop2; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(staop2) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8186 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.staop3; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(staop3) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8187 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.staop4; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(staop4) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8188 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.staop5; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(staop5) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8189 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stacoll1; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stacoll1) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8190 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stacoll2; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stacoll2) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8191 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stacoll3; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stacoll3) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8192 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stacoll4; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stacoll4) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8193 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stacoll5; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stacoll5) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8194 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stanumbers1; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stanumbers1) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8195 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stanumbers2; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stanumbers2) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8196 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stanumbers3; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stanumbers3) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8197 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stanumbers4; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stanumbers4) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8198 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stanumbers5; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stanumbers5) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8199 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stavalues1; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stavalues1) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8200 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stavalues2; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stavalues2) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8201 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stavalues3; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stavalues3) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8202 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stavalues4; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stavalues4) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8203 (class 0 OID 0)
-- Dependencies: 59
-- Name: COLUMN pg_statistic.stavalues5; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(stavalues5) ON TABLE pg_catalog.pg_statistic TO azure_pg_admin;


--
-- TOC entry 8204 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.oid; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(oid) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8205 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subdbid; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subdbid) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8206 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subname; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subname) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8207 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subowner; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subowner) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8208 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subenabled; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subenabled) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8209 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subconninfo; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subconninfo) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8210 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subslotname; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subslotname) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8211 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subsynccommit; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subsynccommit) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


--
-- TOC entry 8212 (class 0 OID 0)
-- Dependencies: 84
-- Name: COLUMN pg_subscription.subpublications; Type: ACL; Schema: pg_catalog; Owner: azuresu
--

GRANT SELECT(subpublications) ON TABLE pg_catalog.pg_subscription TO azure_pg_admin;


-- Completed on 2026-09-28 15:55:01

--
-- PostgreSQL database dump complete
--

\unrestrict zXUY1WtOWUgpHTRHEGsUS2pp9RsN8ZaBnwy5K7N096E2Xhwekm9yOmKgaOKlJFN

