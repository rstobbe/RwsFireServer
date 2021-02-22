function RwsDataConversionStart

port = 9002;
obj = RwsDataConversion(port);
obj.ConnectClient;
DataFile = 'D:\RwsFireClient\Test';
obj.InitiateDataRecord(DataFile);
obj.ReadPortMetaData;