// Demo: consume the generated Kotlin bindings for `starter`.
//
// Two ways to run:
//
//   A. Gradle (see demo/kotlin/README.md) — `./gradlew run`
//   B. Plain kotlinc + JNA, no Gradle — `demo/kotlin/run.sh`
//
// The generated bindings use JNA, so run with:
//     -Djna.library.path=<dir containing libstarter.dylib/.so/.dll>
// and the `starter` library name resolves automatically.

package demo

import uniffi.starter.Counter
import uniffi.starter.ExportS1
import uniffi.starter.Operation
import uniffi.starter.StarterException
import uniffi.starter.add
import uniffi.starter.makeExportS1
import uniffi.starter.roundtripExportS1
import uniffi.starter.version

fun main() {
    println("library version: ${version()}")
    println("add(2, 3) = ${add(2L, 3L)}")

    // --- stateful object -----------------------------------------------------
    val counter = Counter(10)
    counter.apply(Operation.Add(delta = 5))
    counter.setLabel("demo")
    val summary = counter.summary()
    println("counter: ${summary.value} after ${summary.operations} op, label=${summary.label}")

    // --- error mapping -------------------------------------------------------
    try {
        counter.divide(0)
    } catch (e: StarterException.DivisionByZero) {
        println("divide(0) raised DivisionByZero (as expected)")
    }

    // --- ExportS1: every supported type, both directions ---------------------
    val s: ExportS1 = makeExportS1()
    println("\nExportS1 from Rust:")
    println("  flag=${s.flag} i64=${s.i64V} u64=${s.u64V} f64=${s.f64V}")
    println("  text=${s.text} data=${s.data.toList()} tags=${s.tags}")
    println("  scores=${s.scores} createdAt=${s.createdAt} ttl=${s.ttl}")
    println("  child=(${s.child.id}, ${s.child.label}) color=${s.color}")
    println("  children=${s.children.map { Pair(it.id, it.label) }}")
    println("  maybeChild=${s.maybeChild?.id}")

    val echoed = roundtripExportS1(s)
    // Note: Kotlin `data class` equality uses reference equality for array
    // fields (`ByteArray`), so `echoed == s` is false even when every value
    // matches. Compare field-wise; `data` needs contentEquals.
    val equal = echoed.flag == s.flag &&
        echoed.i64V == s.i64V &&
        echoed.u64V == s.u64V &&
        echoed.text == s.text &&
        echoed.data.contentEquals(s.data) &&
        echoed.tags == s.tags &&
        echoed.scores == s.scores &&
        echoed.createdAt == s.createdAt &&
        echoed.ttl == s.ttl &&
        echoed.child == s.child &&
        echoed.color == s.color &&
        echoed.children == s.children &&
        echoed.byName == s.byName &&
        echoed.maybeChild == s.maybeChild
    check(equal) { "round-trip mismatch!" }
    println("  round-trip: OK")
}
