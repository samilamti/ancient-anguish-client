import 'package:ancient_anguish_client/models/meter_condition.dart';
import 'package:ancient_anguish_client/models/text_link_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VitalsReading hp(int hp, [int maxHp = 100]) =>
      VitalsReading(hp: hp, maxHp: maxHp, sp: 50, maxSp: 100);
  VitalsReading sp(int sp, [int maxSp = 90]) =>
      VitalsReading(hp: 50, maxHp: 100, sp: sp, maxSp: maxSp);

  group('Meter', () {
    test('bands run from full to empty', () {
      expect(Meter.hp.bands, ['green', 'orange', 'red', 'dying']);
      expect(Meter.sp.bands, ['navy', 'blue', 'cyan', 'white']);
    });
  });

  group('MeterCondition.firesOn', () {
    const orange = MeterCondition(meter: Meter.hp, band: 'orange');
    const cyan = MeterCondition(meter: Meter.sp, band: 'cyan');

    test('fires on entering the band', () {
      expect(orange.firesOn(hp(61), hp(60)), isTrue);
      expect(cyan.firesOn(sp(46), sp(44)), isTrue); // blue → cyan
    });

    test('does not fire while the meter stays in the band', () {
      expect(orange.firesOn(hp(60), hp(45)), isFalse);
      expect(orange.firesOn(hp(45), hp(45)), isFalse);
    });

    test('does not fire on leaving the band', () {
      expect(orange.firesOn(hp(45), hp(20)), isFalse);
    });

    test('jumping straight past other bands still fires on the target', () {
      expect(const MeterCondition(meter: Meter.hp, band: 'dying')
          .firesOn(hp(90), hp(10)), isTrue);
    });

    test('never fires against an unknown max (the state before login)', () {
      const before = VitalsReading(hp: 0, maxHp: 0, sp: 0, maxSp: 0);
      expect(orange.firesOn(before, hp(50)), isFalse);
      expect(const MeterCondition(meter: Meter.hp, band: 'green')
          .firesOn(before, hp(100)), isFalse);
      expect(orange.firesOn(hp(50), before), isFalse);
    });

    test('direction filters by the way the bar moved', () {
      final falling = orange.copyWith(direction: MeterDirection.falling);
      final rising = orange.copyWith(direction: MeterDirection.rising);
      // Dropping from green into orange.
      expect(falling.firesOn(hp(70), hp(50)), isTrue);
      expect(rising.firesOn(hp(70), hp(50)), isFalse);
      // Healing from red into orange.
      expect(falling.firesOn(hp(20), hp(50)), isFalse);
      expect(rising.firesOn(hp(20), hp(50)), isTrue);
      expect(orange.firesOn(hp(20), hp(50)), isTrue);
    });

    test('watches only its own meter', () {
      // HP crosses into orange while SP holds: an SP rule is unmoved.
      const spOrangeish = MeterCondition(meter: Meter.sp, band: 'blue');
      expect(spOrangeish.firesOn(hp(70), hp(50)), isFalse);
    });

    test('an unknown band never fires', () {
      const bogus = MeterCondition(meter: Meter.sp, band: 'orange');
      expect(bogus.isValid, isFalse);
      expect(bogus.firesOn(sp(90), sp(0)), isFalse);
    });

    test('canFire rules out the impossible directions', () {
      const navy = MeterCondition(meter: Meter.sp, band: 'navy');
      const dying = MeterCondition(meter: Meter.hp, band: 'dying');
      expect(navy.canFire, isTrue);
      expect(navy.copyWith(direction: MeterDirection.falling).canFire, isFalse);
      expect(navy.copyWith(direction: MeterDirection.rising).canFire, isTrue);
      expect(dying.copyWith(direction: MeterDirection.rising).canFire, isFalse);
      expect(dying.copyWith(direction: MeterDirection.falling).canFire, isTrue);
    });

    test('regenerating to full fires navy', () {
      const navy = MeterCondition(meter: Meter.sp, band: 'navy');
      expect(navy.firesOn(sp(70), sp(90)), isTrue);
    });
  });

  group('MeterCondition JSON', () {
    test('round-trips through a TextLinkRule', () {
      const rule = TextLinkRule(
        id: 'ctr_1',
        name: 'Potion',
        pattern: '',
        commandTemplate: 'drink potion',
        meter: MeterCondition(
          meter: Meter.hp,
          band: 'dying',
          direction: MeterDirection.falling,
        ),
      );
      final back = TextLinkRule.fromJson(rule.toJson());
      expect(back.meter, rule.meter);
      expect(back.isMeterTrigger, isTrue);
    });

    test('a line rule writes no meter key and reads back without one', () {
      const rule = TextLinkRule(
        id: 'x',
        name: 'x',
        pattern: 'a',
        commandTemplate: 'b',
      );
      expect(rule.toJson().containsKey('meter'), isFalse);
      expect(TextLinkRule.fromJson(rule.toJson()).meter, isNull);
    });

    test('garbage reads as no condition rather than throwing', () {
      expect(MeterCondition.fromJson(null), isNull);
      expect(MeterCondition.fromJson('hp'), isNull);
      expect(MeterCondition.fromJson({'meter': 'mana', 'band': 'x'}), isNull);
      expect(
        MeterCondition.fromJson({'meter': 'sp', 'band': 'cyan'})!.direction,
        MeterDirection.either,
      );
    });

    test('summary reads as a sentence', () {
      expect(const MeterCondition(meter: Meter.sp, band: 'cyan').summary,
          'SP turns cyan');
      expect(
          const MeterCondition(
            meter: Meter.hp,
            band: 'orange',
            direction: MeterDirection.falling,
          ).summary,
          'HP turns orange when dropping');
    });
  });
}
