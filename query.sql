SELECT name, SUBSTRING(ts, 12, 2) AS hour , MAX(high) AS max_high 
FROM "2020" 
GROUP BY  SUBSTRING(ts, 12, 2), name 
ORDER BY name, SUBSTRING(ts, 12, 2)