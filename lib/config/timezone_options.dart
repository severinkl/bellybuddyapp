class TimezoneOption {
  final String value;
  final String label;

  const TimezoneOption(this.value, this.label);
}

const List<TimezoneOption> timezoneOptions = [
  TimezoneOption('Europe/Berlin', 'Berlin (MEZ/MESZ)'),
  TimezoneOption('Europe/Vienna', 'Wien (MEZ/MESZ)'),
  TimezoneOption('Europe/Zurich', 'Zürich (MEZ/MESZ)'),
  TimezoneOption('Europe/London', 'London (GMT/BST)'),
  TimezoneOption('Europe/Paris', 'Paris (MEZ/MESZ)'),
  TimezoneOption('Europe/Rome', 'Rom (MEZ/MESZ)'),
  TimezoneOption('Europe/Madrid', 'Madrid (MEZ/MESZ)'),
  TimezoneOption('Europe/Amsterdam', 'Amsterdam (MEZ/MESZ)'),
  TimezoneOption('Europe/Brussels', 'Brüssel (MEZ/MESZ)'),
  TimezoneOption('Europe/Warsaw', 'Warschau (MEZ/MESZ)'),
  TimezoneOption('Europe/Prague', 'Prag (MEZ/MESZ)'),
  TimezoneOption('Europe/Stockholm', 'Stockholm (MEZ/MESZ)'),
  TimezoneOption('Europe/Helsinki', 'Helsinki (OEZ/OESZ)'),
  TimezoneOption('Europe/Athens', 'Athen (OEZ/OESZ)'),
  TimezoneOption('Europe/Istanbul', 'Istanbul (TRT)'),
  TimezoneOption('America/New_York', 'New York (EST/EDT)'),
  TimezoneOption('America/Los_Angeles', 'Los Angeles (PST/PDT)'),
  TimezoneOption('Asia/Tokyo', 'Tokio (JST)'),
  TimezoneOption('Australia/Sydney', 'Sydney (AEST/AEDT)'),
];
