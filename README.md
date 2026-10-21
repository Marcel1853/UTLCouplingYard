# UTL Coupling Yard

*Auf Deutsch lesen: [README-de.md](README-de.md).*

Add-on for **Unified Train Logistics (UTL)**: coupling and uncoupling. Trains leave wagons at stations, shunting
locomotives fetch, bring and park them. Made for good-looking stations and role play. Requires UTLogistics 0.0.20
or newer.

## Station roles

Pick them in the UTL station window, below the UTL roles.

- **Wagon yard** – a train stops here and
  - **leaves** all wagons behind its locomotives,
  - **picks up** the wagons waiting ahead of it (up to 40 tiles): it moves slowly forward and couples them,
  - then carries on with its schedule. Wait conditions at this stop do not matter.

  Mode per station: leave and pick up, only leave, only pick up.
- **Shunting depot** – depot for shunting locomotives. UTL never dispatches them. A shunting locomotive must drive
  both ways: at least one locomotive per direction (e.g. one facing left, one facing right). Without a schedule it
  gets the depot as its only stop.
- **Turnaround** – shunting locomotives use it when they can only reach a target after changing direction.

## Shunting

In the station window of a wagon yard, enter **Shunt wagons to:** the name of another wagon yard and choose when:
right away, when empty or when full. Whenever wagons are left there, a free shunting locomotive drives to the end of
the wagons, couples them, brings them to the target, uncouples and returns to its depot.

Example: the train leaves full wagons at "Arrival" → shunting locomotive brings them to "Unloading" → when empty, on
to "Departure" → the next train picks them up there.

Several wagon yards may share a name (e.g. three tracks called "Loading bay"): the shunting locomotive takes a
free one. It arrives pushing the wagons, so dead-end tracks work; if needed it changes direction at a turnaround
first.

## Relay

Let trains run only part of the way and hand the wagons over. Give a wagon yard a **relay number** (station window),
and wire the signal [virtual-signal=ucy-relay] **Relay** with that number to the train stop of a requester (or
provider). Deliveries to it then stop at the wagon yard after loading: the train leaves its wagons there – the
delivery stays with the wagons – and its locomotives return to their depot. The next train that picks up the wagons
at a wagon yard takes the delivery on to the requester.

## Scenario

"UTL Coupling Yard – shunting yard" (new game → scenarios): a large shunting yard with inserters loading and
unloading, plus demo tracks for leaving, picking up, swapping and the relay.

## Tips

- Build stops on the right-hand side in the direction of travel, as usual.
- Leave room ahead of a wagon yard for waiting wagons, and use rail signals so trains do not run into parked wagons.
- A train arriving with its wagons first (pushed) keeps them coupled.
- UTL does not send shunting locomotives to refuel: give them plenty of fuel or a "fuel low" interrupt.

## Performance

No timers while nothing is shunted. Everything starts from UTL events (train arrived, train free in depot, job
finished). Only while a train moves slowly to couple, a short timer runs.

Every coupling is announced to UTL, so deliveries and schedules survive it.

Made with the help of AI (Claude by Anthropic), tested by Marcel171297.
