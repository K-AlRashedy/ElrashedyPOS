import 'dart:io';

enum PrinterTransport { network, usb, pdf }

enum PaperWidth {
  mm80(576, '80mm'),
  mm58(384, '58mm');

  const PaperWidth(this.dots, this.label);
  final int dots;
  final String label;
}

class PrinterConfig {
  PrinterConfig({
    this.transport = PrinterTransport.network,
    this.host = '',
    this.port = 9100,
    this.printerName = '',
    this.width = PaperWidth.mm80,
    this.kickDrawer = false,
    this.enabled = true,
  });

  PrinterTransport transport;
  String host;
  int port;
  String printerName;
  PaperWidth width;
  bool kickDrawer;
  bool enabled;

  bool get isConfigured => switch (transport) {
        PrinterTransport.network => host.trim().isNotEmpty,
        PrinterTransport.usb => printerName.trim().isNotEmpty,
        PrinterTransport.pdf => printerName.trim().isNotEmpty,
      };

  String get describe => switch (transport) {
        PrinterTransport.network => '$host:$port',
        PrinterTransport.usb => printerName,
        PrinterTransport.pdf => printerName,
      };

  Map<String, dynamic> toJson() => {
        'transport': transport.name,
        'host': host,
        'port': port,
        'printer_name': printerName,
        'width': width.name,
        'kick_drawer': kickDrawer,
        'enabled': enabled,
      };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
        transport: PrinterTransport.values.firstWhere(
          (value) => value.name == json['transport'],
          orElse: () => PrinterTransport.network,
        ),
        host: json['host'] as String? ?? '',
        port: (json['port'] as num?)?.toInt() ?? 9100,
        printerName: json['printer_name'] as String? ?? '',
        width: PaperWidth.values.firstWhere((value) => value.name == json['width'], orElse: () => PaperWidth.mm80),
        kickDrawer: json['kick_drawer'] == true,
        enabled: json['enabled'] != false,
      );

  PrinterConfig copy() => PrinterConfig.fromJson(toJson());
}

class PrinterSettings {
  PrinterSettings({
    PrinterConfig? customer,
    PrinterConfig? kitchen,
    this.autoPrintCustomer = true,
    this.autoPrintKitchen = false,
    this.receiptHeader = 'الرشيدي',
    this.receiptFooter = 'شكراً لزيارتكم',
  })  : customer = customer ?? PrinterConfig(),
        kitchen = kitchen ?? PrinterConfig(enabled: false);

  PrinterConfig customer;
  PrinterConfig kitchen;
  bool autoPrintCustomer;
  bool autoPrintKitchen;
  String receiptHeader;
  String receiptFooter;

  Map<String, dynamic> toJson() => {
        'customer': customer.toJson(),
        'kitchen': kitchen.toJson(),
        'auto_print_customer': autoPrintCustomer,
        'auto_print_kitchen': autoPrintKitchen,
        'receipt_header': receiptHeader,
        'receipt_footer': receiptFooter,
      };

  factory PrinterSettings.fromJson(Map<String, dynamic> json) => PrinterSettings(
        customer: PrinterConfig.fromJson(json['customer'] as Map<String, dynamic>? ?? {}),
        kitchen: PrinterConfig.fromJson(json['kitchen'] as Map<String, dynamic>? ?? {}),
        autoPrintCustomer: json['auto_print_customer'] != false,
        autoPrintKitchen: json['auto_print_kitchen'] == true,
        receiptHeader: json['receipt_header'] as String? ?? 'الرشيدي',
        receiptFooter: json['receipt_footer'] as String? ?? 'شكراً لزيارتكم',
      );
}

class AppSettings {
  AppSettings({this.serverUrl = '', String? deviceName, PrinterSettings? printers})
      : deviceName = deviceName ?? _defaultDeviceName(),
        printers = printers ?? PrinterSettings();

  String serverUrl;
  String deviceName;
  PrinterSettings printers;

  static String _defaultDeviceName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'POS terminal';
    }
  }

  Map<String, dynamic> toJson() => {
        'server_url': serverUrl,
        'device_name': deviceName,
        'printers': printers.toJson(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        serverUrl: json['server_url'] as String? ?? '',
        deviceName: json['device_name'] as String? ?? _defaultDeviceName(),
        printers: PrinterSettings.fromJson(json['printers'] as Map<String, dynamic>? ?? {}),
      );
}