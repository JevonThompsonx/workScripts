@echo off
::	Written by JEG to map the default Egnyte Drives for Civils

cd "C:\Program Files (x86)\Egnyte Connect"
EgnyteClient.exe -command remove -l "ashleyvance"
EgnyteClient.exe -command add -l "Sun" -d "ashleyvance" -sso use_sso -t S -m "/Shared/Sun" -c connect_immediately
EgnyteClient.exe -command add -l "All Jobs" -d "ashleyvance" -sso use_sso -t J -m "/Shared/Sun/All Jobs" -c connect_immediately
EgnyteClient.exe -command add -l "Library" -d "ashleyvance" -sso use_sso -t L -m "/Shared/Sun/Library" -c connect_immediately
EgnyteClient.exe -command add -l "Templates" -d "ashleyvance" -sso use_sso -t T -m "/Shared/Sun/Templates/Civil Templates" -c connect_immediately
EgnyteClient.exe -command add -l "Private" -d "ashleyvance" -sso use_sso -t P -m "/Private" -c connect_immediately

