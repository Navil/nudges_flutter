import 'dart:math';
import 'package:intl/intl.dart';
class Config{
  static final int imageHeight = 848;
  static final int imageWidth = 600;

  static guid() {
    s4() {
      return ((1 + Random().nextDouble()) * 0x10000).floor()
          .toString()
          .substring(1);
    }
    return s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
  }

  static String toDate(DateTime date){
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String toDateTime(DateTime dateTime){
    return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
  }
}
