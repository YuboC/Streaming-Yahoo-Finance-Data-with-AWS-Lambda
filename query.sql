SELECT * FROM (SELECT a.name, a.hour, a.ts, b.max_high FROM (SELECT name, high, ts, SUBSTRING(ts, 12, 2) AS hour  FROM "2020" db) a
INNER JOIN (SELECT name, SUBSTRING(ts, 12, 2) AS hour, MAX(high) AS max_high FROM "2020" GROUP BY name, SUBSTRING(ts, 12, 2)) b
ON a.name = b.name AND a.hour = b.hour AND a.high = b.max_high)
ORDER BY name, hour
