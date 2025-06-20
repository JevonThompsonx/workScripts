@echo off
::	Written by JEG to map the default Egnyte Drives for Shared Services Team

cd "C:\Program Files (x86)\Egnyte Connect"
EgnyteClient.exe -command remove -l "ashleyvance"
EgnyteClient.exe -command add -l "Sun" -d "ashleyvance" -sso use_sso -t S -m "/Shared/Sun" -c connect_immediately
EgnyteClient.exe -command add -l "Private" -d "ashleyvance" -sso use_sso -t P -m "/Private" -c connect_immediately

