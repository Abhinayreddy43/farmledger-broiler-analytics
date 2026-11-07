SET search_path TO farmledger;
SELECT disease_reported,
       ROUND(AVG(mortality_pct), 1)   AS avg_mortality_pct,
       ROUND(AVG(net_payable), 0)     AS avg_net_payable
FROM v_batch_kpis
GROUP BY disease_reported;