(SELECT  patientIdentifier AS "Patient Identifier", patientName AS "Patient Name", Age, Gender, age_group, 'Initiated' AS 'Program_Status', sort_order
FROM
                (select distinct patient.patient_id AS Id,
									   patient_identifier.identifier AS patientIdentifier,
									   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
									   floor(datediff(CAST('#endDate#' AS DATE), person.birthdate)/365) AS Age,
									   person.gender AS Gender,
									   observed_age_group.name AS age_group,
									   observed_age_group.sort_order AS sort_order

                from obs o
						-- CLIENTS NEWLY INITIATED ON ART
						 INNER JOIN patient ON o.person_id = patient.patient_id 
						 AND (o.concept_id = 2249 AND DATE(o.value_datetime) BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE))
						 AND patient.voided = 0 AND o.voided = 0
						 AND o.person_id not in (
							select distinct os.person_id from obs os
							where 
								os.concept_id = 3634 AND os.value_coded = 2095 
								AND (os.obs_datetime BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE))
						 )
						 AND o.person_id not in 
								(
								select distinct person_id 
													from person
													where death_date < CAST('#endDate#' AS DATE)
													and dead = 1
								)
						AND o.person_id not in 
								(
								select distinct os.person_id 
							   from obs os
							   where os.concept_id = 4155 and os.value_coded = 2146
							   AND os.obs_datetime BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE)
						)	
						 
						 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0
						 INNER JOIN person_name ON person.person_id = person_name.person_id
						 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
						 INNER JOIN reporting_age_group AS observed_age_group ON
						  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
						  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
                   WHERE observed_age_group.report_group_name = 'Modified_Ages') AS Newly_Initiated_ART_Clients
ORDER BY Newly_Initiated_ART_Clients.Age)

UNION

(SELECT patientIdentifier AS "Patient Identifier", patientName AS "Patient Name", Age, Gender, age_group, 'Seen' AS 'Program_Status', sort_order
FROM (

select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(CAST('#endDate#' AS DATE), person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order
        from obs o
								-- CLIENTS SEEN FOR ART
                                 INNER JOIN patient ON o.person_id = patient.patient_id
                                 AND (o.concept_id = 3843 AND o.value_coded = 3841 OR o.value_coded = 3842)
                                 AND (DATE(o.obs_datetime) BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE))
                                 AND patient.voided = 0 AND o.voided = 0
                                 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0
                                 INNER JOIN person_name ON person.person_id = person_name.person_id
                                 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
								 INNER JOIN reporting_age_group AS observed_age_group ON
									  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
									  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages'

) AS Clients_Seen

WHERE Clients_Seen.Id not in (
		select distinct patient.patient_id AS Id
		from obs o
				-- CLIENTS NEWLY INITIATED ON ART
				 INNER JOIN patient ON o.person_id = patient.patient_id
				 AND (o.concept_id = 2249 AND DATE(o.value_datetime) BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE))
				 AND patient.voided = 0 AND o.voided = 0
				and patient.patient_id not in(
											select distinct os.person_id from obs os															 
											where os.concept_id = 2396 														 
											AND (os.obs_datetime BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE))
											)
							)
AND Clients_Seen.Id not in (
				select distinct os.person_id 
				from obs os
				where os.concept_id = 4155 and os.value_coded = 2146
				AND os.obs_datetime BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE)
		)

AND Clients_Seen.Id not in 
			(
			select distinct person_id 
			from person
			where death_date < CAST('#endDate#' AS DATE)
			and dead = 1
			)

ORDER BY Clients_Seen.Age)

UNION


-- INCLUDE MISSED APPOINTMENTS WITHIN 28 DAYS ACCORDING TO THE NEW PEPFAR GUIDELINE
(SELECT patientIdentifier AS "Patient Identifier", patientName AS "Patient Name", Age, Gender, age_group, 'MissedWithin28Days' AS 'Program_Status', sort_order
FROM
                (select distinct patient.patient_id AS Id,
									   patient_identifier.identifier AS patientIdentifier,
									   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
									   floor(datediff(CAST('#endDate#' AS DATE), person.birthdate)/365) AS Age,
									   person.gender AS Gender,
									   observed_age_group.name AS age_group,
									   observed_age_group.sort_order AS sort_order

                from obs o
						-- PATIENTS WHO HAVE NOT RECEIVED ARV's WITHIN 4 WEEKS (i.e. 28 days) OF THIER LAST MISSED DRUG PICK-UP
						 inner join patient on o.person_id = patient.patient_id
						 and patient.voided = 0 AND o.voided = 0
						 and o.concept_id = 3752
						 and o.obs_id in (
								select os.obs_id
								from obs os
								where os.concept_id=3752
								and os.obs_id in (
									select observation_id
									from
										(select SUBSTRING(MAX(CONCAT(oss.obs_datetime, oss.obs_id)), 20) AS observation_id, max(oss.obs_datetime)
										from obs oss 
											inner join person p on oss.person_id=p.person_id and oss.concept_id = 3752 and oss.voided=0
											and oss.value_datetime < cast('#endDate#' as date)
										group by p.person_id) as latest_followup_obs
								)
								and os.value_datetime < cast('#endDate#' as date)
								and datediff(cast('#endDate#' as date), os.value_datetime) between 0 and 28
						 )
						 
						 and o.person_id not in (
								select distinct os.person_id
								from obs os
								where (os.concept_id = 3843 AND os.value_coded = 3841 OR os.value_coded = 3842)
								AND os.obs_datetime BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE)
						 )

						 and o.person_id not in (
							select os.person_id 
							from obs os
							where os.concept_id = 4155 and os.value_coded = 2146 and os.obs_datetime <= cast('#endDate#' as date)
							and os.person_id not in (
								select seen.person_id 
								from (
										select oss.person_id, max(oss.value_datetime) latest
										from obs oss
										where oss.concept_ID = 2266
										and oss.value_datetime <= cast('#endDate#' as date)
										group by oss.person_id
									 ) tout,
									 (
										select oss.person_id, oss.obs_datetime 
										from obs oss
										where oss.concept_id = 3843
										and oss.obs_datetime <= cast('#endDate#' as date)
									 ) seen
								 where tout.person_id = seen.person_id
								 and date(seen.obs_datetime) > date(tout.latest)
						   )
						 )									

						 and o.person_id not in (
									select person_id 
									from person 
									where death_date <= cast('#endDate#' as date)
									and dead = 1
						 )
						 
						 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0
						 INNER JOIN person_name ON person.person_id = person_name.person_id
						 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1						 
						 INNER JOIN reporting_age_group AS observed_age_group ON
						 CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
						 AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
                   WHERE 	observed_age_group.report_group_name = 'Modified_Ages' AND
							o.person_id not in (
							-- HAVE TO FIND A BETTER SOLUTION FOR THIS INNER QUERY (STORED PROC OR STORED FUNCTION)
						    select patient.patient_id
										from obs os
												-- CAME IN PREVIOUS 1 MONTH AND WAS GIVEN (2, 3, 4, 5, 6 MONHTS SUPPLY OF DRUGS)
												 INNER JOIN patient ON os.person_id = patient.patient_id
												  AND MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) and YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH))
												  AND patient.voided = 0 AND os.voided = 0 
												  AND (os.concept_id = 4174 and (os.value_coded = 4176 or os.value_coded = 4177 or os.value_coded = 4245 or os.value_coded = 4246 or os.value_coded = 4247)))
						    AND 
							o.person_id not in (
							select patient.patient_id
											from obs os
											-- CAME IN PREVIOUS 2 MONTHS AND WAS GIVEN (3, 4, 5, 6 MONHTS SUPPLY OF DRUGS)
											 INNER JOIN patient ON os.person_id = patient.patient_id 
												 AND MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
												 AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
												 AND patient.voided = 0 AND os.voided = 0
												 AND os.concept_id = 4174 and (os.value_coded = 4177 or os.value_coded = 4245 or os.value_coded = 4246 or os.value_coded = 4247))

						    AND
							o.person_id not in (						  
							select patient.patient_id
											from obs os
											-- CAME IN PREVIOUS 3 MONTHS AND WAS GIVEN (4, 5, 6 MONHTS SUPPLY OF DRUGS)
											 INNER JOIN patient ON os.person_id = patient.patient_id 
												 AND MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
												 AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
												 AND patient.voided = 0 AND os.voided = 0 
												 AND os.concept_id = 4174 and (os.value_coded = 4245 or os.value_coded = 4246 or os.value_coded = 4247))

							AND
							o.person_id not in (
							select patient.patient_id

											from obs os
											-- CAME IN PREVIOUS 4 MONTHS AND WAS GIVEN (5, 6 MONHTS SUPPLY OF DRUGS)
											 INNER JOIN patient ON os.person_id = patient.patient_id 
												 AND MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
												 AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
												 AND patient.voided = 0 AND os.voided = 0 
												 AND os.concept_id = 4174 and (os.value_coded = 4246 or os.value_coded = 4247))
							AND
							o.person_id not in (
							select patient.patient_id

											from obs os
											-- CAME IN PREVIOUS 5 MONTHS AND WAS GIVEN (6 MONHTS SUPPLY OF DRUGS)
											 INNER JOIN patient ON os.person_id = patient.patient_id 
												 AND MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
												 AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
												 AND patient.voided = 0 AND os.voided = 0 
												 AND os.concept_id = 4174 and os.value_coded = 4247)
									
							AND
							o.person_id not in (
							select patient.patient_id
											from obs o
											 INNER JOIN patient ON o.person_id = patient.patient_id
												 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) 
												 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) 
												 AND patient.voided = 0 AND o.voided = 0 
												 AND o.concept_id = 4174 and o.value_coded = 4175
												 AND o.person_id in (
													select distinct os.person_id from obs os
													where 
														MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) 
														AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH))
														AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28			
											))
							AND
							o.person_id not in (
											select patient.patient_id
											from obs o
											 INNER JOIN patient ON o.person_id = patient.patient_id
												 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
												 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
												 AND patient.voided = 0 AND o.voided = 0 
												 AND o.concept_id = 4174 and o.value_coded = 4176
												 AND o.person_id in (
													select distinct os.person_id 
													from obs os
													where 
														MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
														AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH))
														AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
															
											))
							AND
							o.person_id not in (
							select distinct patient.patient_id AS Id
											from obs o
											 INNER JOIN patient ON o.person_id = patient.patient_id
												 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
												 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
												 AND patient.voided = 0 AND o.voided = 0 
												 AND o.concept_id = 4174 and o.value_coded = 4177
												 AND o.person_id in (
													select distinct os.person_id from obs os
													where 
														MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
														AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH))
														AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
											))
							AND
							o.person_id not in (
							select distinct patient.patient_id
											from obs o
											 INNER JOIN patient ON o.person_id = patient.patient_id
												 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
												 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
												 AND patient.voided = 0 AND o.voided = 0 
												 AND o.concept_id = 4174 and o.value_coded = 4245
												 AND o.person_id in (
													select distinct os.person_id from obs os
													where 
														MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
														AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH))
														AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
															
											))
							AND
							o.person_id not in (
							select distinct patient.patient_id AS Id
											from obs o
											 INNER JOIN patient ON o.person_id = patient.patient_id
												 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
												 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
												 AND patient.voided = 0 AND o.voided = 0 
												 AND o.concept_id = 4174 and o.value_coded = 4246
												 AND o.person_id in (
													select distinct os.person_id from obs os
													where 
														MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
														AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH))
														AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
															
											))
							AND
							o.person_id not in (
							select distinct patient.patient_id
											from obs o
											 INNER JOIN patient ON o.person_id = patient.patient_id
												 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH)) 
												 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH)) 
												 AND patient.voided = 0 AND o.voided = 0 
												 AND o.concept_id = 4174 and o.value_coded = 4247
												 AND o.person_id in (
													select distinct os.person_id from obs os
													where 
														MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH)) 
														AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH))
														AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
											))
				   ) AS TwentyEightDayDefaulters)
		   

UNION

(SELECT patientIdentifier AS "Patient Identifier", patientName AS "Patient Name", Age, Gender, age_group, 'Seen_Prev_Months' AS 'Program_Status', sort_order
FROM (
(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(CAST('#endDate#' AS DATE), person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

        from obs o
				-- CAME IN PREVIOUS 1 MONTH AND WAS GIVEN (2, 3, 4, 5, 6 MONHTS SUPPLY OF DRUGS)
                 INNER JOIN patient ON o.person_id = patient.patient_id 
				  AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) and YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) AND patient.voided = 0 AND o.voided = 0 
				  AND (o.concept_id = 4174 and (o.value_coded = 4176 or o.value_coded = 4177 or o.value_coded = 4245 or o.value_coded = 4246 or o.value_coded = 4247))
                 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0
				 INNER JOIN person_name ON person.person_id = person_name.person_id
				 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
                 INNER JOIN reporting_age_group AS observed_age_group ON
						  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
						  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')

UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
				-- CAME IN PREVIOUS 2 MONTHS AND WAS GIVEN (3, 4, 5, 6 MONHTS SUPPLY OF DRUGS)
                 INNER JOIN patient ON o.person_id = patient.patient_id 
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and (o.value_coded = 4177 or o.value_coded = 4245 or o.value_coded = 4246 or o.value_coded = 4247)
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')
	   
UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
				-- CAME IN PREVIOUS 3 MONTHS AND WAS GIVEN (4, 5, 6 MONHTS SUPPLY OF DRUGS)
                 INNER JOIN patient ON o.person_id = patient.patient_id 
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and (o.value_coded = 4245 or o.value_coded = 4246 or o.value_coded = 4247)
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0			 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')

UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
				-- CAME IN PREVIOUS 4 MONTHS AND WAS GIVEN (5, 6 MONHTS SUPPLY OF DRUGS)
                 INNER JOIN patient ON o.person_id = patient.patient_id 
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and (o.value_coded = 4246 or o.value_coded = 4247)
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')



UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
				-- CAME IN PREVIOUS 5 MONTHS AND WAS GIVEN (6 MONHTS SUPPLY OF DRUGS)
                 INNER JOIN patient ON o.person_id = patient.patient_id 
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and o.value_coded = 4247
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')
		

UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
                 INNER JOIN patient ON o.person_id = patient.patient_id
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and o.value_coded = 4175
					 AND o.person_id in (
						select distinct os.person_id from obs os
						where 
							MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH)) 
							AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -1 MONTH))
							AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28	
					 )
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')


UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
                 INNER JOIN patient ON o.person_id = patient.patient_id
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and o.value_coded = 4176
					 AND o.person_id in (
						select distinct os.person_id from obs os
						where 
							MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH)) 
							AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -2 MONTH))
							AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
								
					 )
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')
		   
UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
                 INNER JOIN patient ON o.person_id = patient.patient_id
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and o.value_coded = 4177
					 AND o.person_id in (
						select distinct os.person_id from obs os
						where 
							MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH)) 
							AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -3 MONTH))
							AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
								
					 )
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')
		   
UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
                 INNER JOIN patient ON o.person_id = patient.patient_id
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and o.value_coded = 4245
					 AND o.person_id in (
						select distinct os.person_id from obs os
						where 
							MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH)) 
							AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -4 MONTH))
							AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
								
					 )
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')



UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
                 INNER JOIN patient ON o.person_id = patient.patient_id
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and o.value_coded = 4246
					 AND o.person_id in (
						select distinct os.person_id from obs os
						where 
							MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH)) 
							AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -5 MONTH))
							AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28	
					 )
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages')



UNION

(select distinct patient.patient_id AS Id,
                                   patient_identifier.identifier AS patientIdentifier,
                                   concat(person_name.given_name, ' ', person_name.family_name) AS patientName,
                                   floor(datediff(o.obs_datetime, person.birthdate)/365) AS Age,
                                   person.gender AS Gender,
                                   observed_age_group.name AS age_group,
								   observed_age_group.sort_order AS sort_order

                from obs o
                 INNER JOIN patient ON o.person_id = patient.patient_id
					 AND MONTH(o.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH)) 
					 AND YEAR(o.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH)) 
					 AND patient.voided = 0 AND o.voided = 0 
					 AND o.concept_id = 4174 and o.value_coded = 4247
					 AND o.person_id in (
						select distinct os.person_id from obs os
						where 
							MONTH(os.obs_datetime) = MONTH(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH)) 
							AND YEAR(os.obs_datetime) = YEAR(DATE_ADD(CAST('#endDate#' AS DATE), INTERVAL -6 MONTH))
							AND os.concept_id = 3752 AND DATEDIFF(os.value_datetime, CAST('#endDate#' AS DATE)) BETWEEN 0 AND 28
					 )
					 INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0				 
					 INNER JOIN person_name ON person.person_id = person_name.person_id
					 INNER JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.identifier_type = 3 AND patient_identifier.preferred=1
					 INNER JOIN reporting_age_group AS observed_age_group ON
							  CAST('#endDate#' AS DATE) BETWEEN (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.min_years YEAR), INTERVAL observed_age_group.min_days DAY))
							  AND (DATE_ADD(DATE_ADD(person.birthdate, INTERVAL observed_age_group.max_years YEAR), INTERVAL observed_age_group.max_days DAY))
           WHERE observed_age_group.report_group_name = 'Modified_Ages'	)	   
		   
) AS ARTCurrent_PrevMonths
 
WHERE ARTCurrent_PrevMonths.Id not in (
				SELECT os.person_id 
				FROM obs os
				WHERE (os.concept_id = 3843 AND os.value_coded = 3841 OR os.value_coded = 3842)
				AND (DATE(os.obs_datetime) BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE))
										)
and ARTCurrent_PrevMonths.Id not in (
	           select distinct patient.patient_id AS Id
	           from obs o
	                       -- CLIENTS NEWLY INITIATED ON ART
				INNER JOIN patient ON o.person_id = patient.patient_id													
				AND (o.concept_id = 2249 
				AND DATE(o.value_datetime) BETWEEN CAST('#startDate#' AS DATE) AND CAST('#endDate#' AS DATE))
				AND patient.voided = 0 AND o.voided = 0)
AND ARTCurrent_PrevMonths.Id not in (
				select distinct os.person_id 
				from obs os
				where os.concept_id = 4155 and os.value_coded = 2146
		)
AND ARTCurrent_PrevMonths.Id not in (
			select person_id 
			from person 
			where death_date < CAST('#endDate#' AS DATE)
			and dead = 1
			)
ORDER BY ARTCurrent_PrevMonths.Age)

