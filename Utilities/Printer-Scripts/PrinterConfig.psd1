@{
    BasePath = 'C:\PrinterDrivers'
    DriverSharePath = '\\fileserver\PrinterDrivers'
    LogRoot = 'C:\ProgramData\PrinterScripts\Logs'
    LocalStageRoot = 'C:\ProgramData\PrinterScripts\Drivers'

    Printers = @(
        @{
            Key = 'HQ_RicohColor'
            PrinterName = 'HQ - Ricoh IM C2510'
            IPAddress = '192.0.2.10'
            DriverFolder = 'HQ - Ricoh IM C2510 - 192.0.2.10'
            InfFile = 'oemsetup.inf'
            DriverName = 'RICOH IM C2510 PCL 6'
        },
        @{
            Key = 'HQ_BrotherMono'
            PrinterName = 'HQ - Brother HL-L6210DW'
            IPAddress = '192.0.2.11'
            DriverFolder = 'HQ - Brother HL-L6210DW - 192.0.2.11'
            InfFile = 'BROHL20A.INF'
            DriverName = 'Brother HL-L6210DW series'
        },
        @{
            Key = 'Branch_RicohColor'
            PrinterName = 'BRANCH - Ricoh MP C4502'
            IPAddress = '198.51.100.10'
            DriverFolder = 'BRANCH - Ricoh MP C4502 - 198.51.100.10'
            InfFile = 'OEMSETUP.INF'
            DriverName = 'RICOH Aficio MP C4502 PCL 6'
        },
        @{
            Key = 'Warehouse_HPPlotter'
            PrinterName = 'WAREHOUSE - HP DesignJet 500'
            IPAddress = '203.0.113.10'
            DriverFolder = 'WAREHOUSE - HP DesignJet 500 - 203.0.113.10'
            InfFile = 'hpc500p.inf'
            DriverName = 'HP DesignJet 500 42 by HP'
        }
    )
}
