#module EW

import NIDAQ, CSV, DataFrames, Dates

export init, arb

const dev = "Dev1"

function init(volt)
    println("Disconnect (toggle off add) voltage and press Enter")
    readline()
    NIDAQ.ResetDevice(codeunits(name))
    ao0 = NIDAQ.analog_output("$dev/ao0")
    NIDAQ.start(ao0)
    NIDAQ.write(ao0,[volt])
    NIDAQ.clear(ao0)
    println("Output 0 = $volt V. Connect (toggle on add) voltage.")
end

stamp = Dates.DateFormat("yymmdd_HHMMSS.c\\sv")

function arb(period, volts)
    wt = 1.01*period*(2+length(volts))./80e6
    println("$(period/80) us = $(80e6 / period) Hz will take $wt seconds")
    println("Set up video camera trigger then press Enter")
    readline()
    ct = NIDAQ.generate_pulses("$dev/ctr1", high = 240, low = period - 240)
    NIDAQ.CfgImplicitTiming(ct.th, NIDAQ.Val_FiniteSamps , length(volts))
    ao = NIDAQ.analog_output("$dev/ao0", range=[minimum(volts),maximum(volts)])
    NIDAQ.CfgSampClkTiming(ao.th, pointer("Ctr1InternalOutput"), 4000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, length(volts))
    NIDAQ.write(ao, volts)
    ai = NIDAQ.analog_input("$dev/ai0:3")
    NIDAQ.CfgSampClkTiming(ai.th, pointer("Ctr1InternalOutput"), 4000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, length(volts))
    NIDAQ.start(ai); NIDAQ.start(ao); NIDAQ.start(ct)
    sleep(wt) # clock is 80MHz
    Vi = NIDAQ.read(ai, Float64, length(volts))
    df = DataFrames.DataFrame(Vo = volts, I = Vi[:,1] ./ 1e5, V1 = Vi[:,1], Vx = Vi[:,2], Vy = Vi[:,3], V4 = Vi[:,4])
    fn = Dates.format(Dates.now(),stamp)
    CSV.write(fn, df)
    NIDAQ.clear(ai); NIDAQ.clear(ao); NIDAQ.clear(ct)
    fn
end

#end
