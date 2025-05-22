import 'package:flutter_test/flutter_test.dart';
import 'package:audio_app/tool_services.dart'; // Adjust import path if needed, assuming 'audio_app' is the package name

void main() {
  group('ToolServices Tests', () {
    group('get_weather', () {
      test('returns weather data for a valid city', () async {
        final weather = await get_weather('London');
        expect(weather['city'], 'London');
        expect(weather['temperature'], isA<double>());
        expect(weather.containsKey('condition'), isTrue);
        expect(weather.containsKey('humidity'), isTrue);
        expect(weather.containsKey('wind_speed_kmh'), isTrue);
        expect(weather.containsKey('error'), isFalse);
      });

      test('returns error for city "error"', () async {
        final weather = await get_weather('error');
        expect(weather.containsKey('error'), isTrue);
        expect(weather['error'], 'Failed to fetch weather for error due to simulated error.');
      });

       test('returns error for city "Error" (case-insensitivity check for "error" simulation)', () async {
        final weather = await get_weather('Error');
        expect(weather.containsKey('error'), isTrue);
        expect(weather['error'], 'Failed to fetch weather for Error due to simulated error.');
      });
    });

    group('get_stock_price', () {
      test('returns stock data for a valid symbol', () async {
        final stock = await get_stock_price('GOOGL');
        expect(stock['symbol'], 'GOOGL');
        expect(stock['price'], isA<double>());
        expect(stock.containsKey('currency'), isTrue);
        expect(stock.containsKey('change_percent'), isTrue);
        expect(stock.containsKey('volume'), isTrue);
        expect(stock.containsKey('market_cap_billion'), isTrue);
        expect(stock.containsKey('error'), isFalse);
      });

      test('returns error for symbol "ERROR"', () async {
        final stock = await get_stock_price('ERROR');
        expect(stock.containsKey('error'), isTrue);
        expect(stock['error'], 'Failed to fetch stock price for ERROR due to simulated error.');
      });

      test('returns error for symbol "error" (case-insensitivity check for "ERROR" simulation)', () async {
        final stock = await get_stock_price('error');
        expect(stock.containsKey('error'), isTrue);
        expect(stock['error'], 'Failed to fetch stock price for error due to simulated error.');
      });
    });
  });
}
