# Streaming-Yahoo-Finance-Data-with-AWS-Lambda
[![GitHub stars](https://img.shields.io/github/stars/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda.svg?style=flat&label=Star)](https://github.com/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda.svg?style=flat&label=Fork)](https://github.com/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda/fork)
[![GitHub watchers](https://img.shields.io/github/watchers/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda.svg?style=flat&label=Watch)](https://github.com/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda/watchers)

For this project, I am providing a few Lambda functions to generate near real time finance data records for downstream processing and interactive querying.

This project leads me through the process of consuming “real time” data, processing the data and then dumping it in a manner that facilitates querying and further analysis, either in real time or near real time capacity.

## Infrastructure
This project consists of three major infrastructure elements that work in tandem:
  1. A lambda function that collects our data (DataCollector)
  2. A lambda function that transforms and places data into S3 (DataTransformer)
  3. A serverless process that allows us to query our s3 data (DataAnalyzer)  
  
  - Workflow:
  ![Workflow](https://github.com/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda/blob/master/screen%20shot/iShot2020-05-25PM12.11.50.png)  
  
## AWS SETTINGS
  
### DATA COLLECTOR LAMBDA
  - Lambda Function URL: https://3l0h388o8h.execute-api.us-east-1.amazonaws.com/default/datacollector
  - Basic settings: `Timeout: 15min`, `Memory(MB): 1024`, `attach policy: AmazonKinesisFirehoseFullAccess`, `API Gateway`
    ```python
    import json
    import boto3
    import os
    import subprocess
    import sys

    subprocess.check_call([sys.executable, "-m", "pip", "install", "--target", "/tmp", 'yfinance'])
    sys.path.append('/tmp')

    import yfinance as yf

    tickers = ['FB', 'SHOP', 'BYND', 'NFLX', 'PINS', 'SQ', 'TTD', 'OKTA', 'SNAP', 'DDOG']

    def lambda_handler(event, context):
      # initialize boto3 client
      fh = boto3.client("firehose", "us-east-1")

      for ticker in tickers:
          data = yf.download(ticker, start='2020-05-14', end='2020-05-15', interval = "1m")
          for datetime, value in data.iterrows():
              record = {'high': value['High'], 'low': value['Low'],'ts': str(datetime), 'name': ticker}
              
              # convert it to JSON -- IMPORTANT!!
              as_jsonstr = json.dumps(record)
             
              # this actually pushed to our firehose datastream
              # we must "encode" in order to convert it into the
              # bytes datatype as all of AWS libs operate over
              # bytes not strings
              fh.put_record(

                  DeliveryStreamName="yahoo-finance-stream", 
                  Record={"Data": as_jsonstr.encode('utf-8')})
      return {
          'statusCode': 200,
          'body': json.dumps(f'Done! Recorded: {as_jsonstr}')
      }
     ```
    - DataCollector Lambda configuration page:  
     ![DataCollector Lambda configuration page](https://github.com/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda/blob/master/screen%20shot/iShot2020-05-24PM08.04.47.png)

### KINESIS & DATA TRANSFORMER LAMBDA
  - create new Kinesis Data Firehose - Create delivery stream
  - enable `Data Transformation` with new lambda function
    Basic settings: `Timeout: 1min`, `Memory(MB): 128`, `without trigger`
    ```python
    import json

    def lambda_handler(event, context):
        output_records = []
        for record in event["records"]:
            output_records.append({
                "recordId": record['recordId'],
                "result": "Ok",
                "data": record["data"] + "Cg==" #split the data in single lines
            })
        return {"records": output_records}
      ```
      - Kinesis Data Firehose Delivery Stream Monitoring:
      ![Kinesis Data Firehose Delivery Stream Monitoring](https://github.com/YuboC/Streaming-Yahoo-Finance-Data-with-AWS-Lambda/blob/master/screen%20shot/iShot2020-05-24PM08.03.56.png)
        
### Data Analysis
We want to prep this data gathered for analysis! To do so, set up a Glue crawler so that we can run AWS Athena queries against your data. Then, in Athena, write and run a query that gives us the highest hourly stock “high” per company from the list above.

## AWS Athena
  ```SQL
SELECT * FROM (SELECT a.name, a.hour, a.ts, b.max_high FROM (SELECT name, high, ts, SUBSTRING(ts, 12, 2) AS hour  FROM "2020" db) a
INNER JOIN (SELECT name, SUBSTRING(ts, 12, 2) AS hour, MAX(high) AS max_high FROM "2020" GROUP BY name, SUBSTRING(ts, 12, 2)) b
ON a.name = b.name AND a.hour = b.hour AND a.high = b.max_high)
ORDER BY name, hour
  ```
  |name|hour|ts                       |max_high   |
|----|----|-------------------------|-----------|
|BYND|9   |2020-05-14 09:39:00-04:00|137.9700012|
|BYND|10  |2020-05-14 10:31:00-04:00|139.5599976|
|BYND|11  |2020-05-14 11:15:00-04:00|141        |
|BYND|12  |2020-05-14 12:57:00-04:00|138.2400055|
|BYND|13  |2020-05-14 13:00:00-04:00|137.7899017|
|BYND|14  |2020-05-14 14:12:00-04:00|135.7301025|
|BYND|15  |2020-05-14 15:54:00-04:00|135.8500061|
|DDOG|9   |2020-05-14 09:32:00-04:00|67.25      |
|DDOG|10  |2020-05-14 10:09:00-04:00|66.55000305|
|DDOG|11  |2020-05-14 11:06:00-04:00|65         |
|DDOG|11  |2020-05-14 11:16:00-04:00|65         |
|DDOG|11  |2020-05-14 11:05:00-04:00|65         |
|DDOG|11  |2020-05-14 11:20:00-04:00|65         |
|DDOG|12  |2020-05-14 12:54:00-04:00|64.87999725|
|DDOG|13  |2020-05-14 13:02:00-04:00|65         |
|DDOG|14  |2020-05-14 14:48:00-04:00|64.12999725|
|DDOG|15  |2020-05-14 15:54:00-04:00|65.86990356|
|FB  |9   |2020-05-14 09:37:00-04:00|203.8677979|
|FB  |10  |2020-05-14 10:53:00-04:00|203.3500061|
|FB  |11  |2020-05-14 11:37:00-04:00|204.2700043|
|FB  |12  |2020-05-14 12:56:00-04:00|205.1000061|
|FB  |13  |2020-05-14 13:32:00-04:00|205.6399994|
|FB  |14  |2020-05-14 14:29:00-04:00|204.9850006|
|FB  |15  |2020-05-14 15:59:00-04:00|206.9299927|
|NFLX|9   |2020-05-14 09:36:00-04:00|452        |
|NFLX|10  |2020-05-14 10:08:00-04:00|446.5100098|
|NFLX|11  |2020-05-14 11:16:00-04:00|440.6400146|
|NFLX|12  |2020-05-14 12:59:00-04:00|440.3399963|
|NFLX|13  |2020-05-14 13:49:00-04:00|441.7799988|
|NFLX|14  |2020-05-14 14:30:00-04:00|441.4400024|
|NFLX|15  |2020-05-14 15:59:00-04:00|442.1400146|
|OKTA|9   |2020-05-14 09:39:00-04:00|178        |
|OKTA|9   |2020-05-14 09:38:00-04:00|178        |
|OKTA|10  |2020-05-14 10:10:00-04:00|177.8067932|
|OKTA|11  |2020-05-14 11:37:00-04:00|179.8899994|
|OKTA|12  |2020-05-14 12:57:00-04:00|179.0050049|
|OKTA|13  |2020-05-14 13:02:00-04:00|178.5      |
|OKTA|13  |2020-05-14 13:03:00-04:00|178.5      |
|OKTA|14  |2020-05-14 14:32:00-04:00|177.8099976|
|OKTA|15  |2020-05-14 15:05:00-04:00|177.8500061|
|PINS|9   |2020-05-14 09:31:00-04:00|16.54000092|
|PINS|9   |2020-05-14 09:32:00-04:00|16.54000092|
|PINS|10  |2020-05-14 10:54:00-04:00|16.67499924|
|PINS|10  |2020-05-14 10:53:00-04:00|16.67499924|
|PINS|11  |2020-05-14 11:18:00-04:00|16.94499969|
|PINS|12  |2020-05-14 12:57:00-04:00|17.04000092|
|PINS|13  |2020-05-14 13:26:00-04:00|17.03000069|
|PINS|14  |2020-05-14 14:21:00-04:00|16.90500069|
|PINS|14  |2020-05-14 14:22:00-04:00|16.90500069|
|PINS|15  |2020-05-14 15:51:00-04:00|17.09000015|
|PINS|15  |2020-05-14 15:50:00-04:00|17.09000015|
|SHOP|9   |2020-05-14 09:31:00-04:00|758.0900269|
|SHOP|10  |2020-05-14 10:10:00-04:00|752        |
|SHOP|10  |2020-05-14 10:12:00-04:00|752        |
|SHOP|11  |2020-05-14 11:16:00-04:00|757.4699707|
|SHOP|12  |2020-05-14 12:57:00-04:00|754.1599731|
|SHOP|13  |2020-05-14 13:01:00-04:00|755.8200073|
|SHOP|14  |2020-05-14 14:57:00-04:00|751.7999878|
|SHOP|15  |2020-05-14 15:50:00-04:00|755.5700073|
|SNAP|9   |2020-05-14 09:31:00-04:00|16.72999954|
|SNAP|10  |2020-05-14 10:54:00-04:00|16.93000031|
|SNAP|11  |2020-05-14 11:07:00-04:00|17.14999962|
|SNAP|12  |2020-05-14 12:57:00-04:00|16.98999977|
|SNAP|13  |2020-05-14 13:31:00-04:00|17         |
|SNAP|14  |2020-05-14 14:57:00-04:00|16.92000008|
|SNAP|14  |2020-05-14 14:58:00-04:00|16.92000008|
|SNAP|15  |2020-05-14 15:09:00-04:00|16.96999931|
|SNAP|15  |2020-05-14 15:08:00-04:00|16.96999931|
|SQ  |9   |2020-05-14 09:46:00-04:00|72.80999756|
|SQ  |10  |2020-05-14 10:59:00-04:00|75.58999634|
|SQ  |11  |2020-05-14 11:09:00-04:00|76.48999786|
|SQ  |12  |2020-05-14 12:59:00-04:00|76.75      |
|SQ  |13  |2020-05-14 13:48:00-04:00|77.18000031|
|SQ  |14  |2020-05-14 14:59:00-04:00|77.26000214|
|SQ  |15  |2020-05-14 15:57:00-04:00|78.25      |
|TTD |9   |2020-05-14 09:31:00-04:00|289.4498901|
|TTD |10  |2020-05-14 10:53:00-04:00|290.0700073|
|TTD |11  |2020-05-14 11:18:00-04:00|296.8562927|
|TTD |12  |2020-05-14 12:57:00-04:00|294.5      |
|TTD |13  |2020-05-14 13:31:00-04:00|296        |
|TTD |14  |2020-05-14 14:59:00-04:00|295.769989 |
|TTD |15  |2020-05-14 15:24:00-04:00|297.6700134|
