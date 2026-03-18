@echo off
::	Written by JEG to map the default Egnyte Drives for spare computers

cd "C:\Program Files (x86)\Egnyte Connect"
EgnyteClient.exe -command remove -l "ashleyvance"
EgnyteClient.exe -command add -l "Sun" -d "ashleyvance" -sso use_sso -t S -m "/Shared/Sun" -c connect_immediately
EgnyteClient.exe -command add -l "All Jobs" -d "ashleyvance" -sso use_sso -t J -m "/Shared/Sun/All Jobs" -c connect_immediately
EgnyteClient.exe -command add -l "Library" -d "ashleyvance" -sso use_sso -t L -m "/Shared/Sun/Library" -c connect_immediately
EgnyteClient.exe -command add -l "Templates" -d "ashleyvance" -sso use_sso -t T -m "/Shared/Sun/Templates" -c connect_immediately
EgnyteClient.exe -command add -l "Vectorworks" -d "ashleyvance" -sso use_sso -t V -m "/Shared/Sun/Vectorworks" -c connect_immediately
EgnyteClient.exe -command add -l "Mars" -d "ashleyvance" -sso use_sso -t M -m "/Shared/Sun/Mars" -c connect_immediately
