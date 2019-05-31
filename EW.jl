#module EW

import NIDAQ, CSV, DataFrames, Dates

export @init

function init(name, volt)
    println("Disconnect (toggle off add) voltage.")
    sleep(10)
    NIDAQ.ResetDevice(codeunits(name))
    ao0 = NIDAQ.analog_output("$name/ao0")
    NIDAQ.start(ao0)
    NIDAQ.write(ao0,[volt])
    NIDAQ.clear(ao0)
    println("Output 0 = $volt V. Connect (toggle on add) voltage.")
end

stamp = Dates.DateFormat("yymmdd_HHMMSS.c\\sv")

function arb(name, period, volts)
    ct = NIDAQ.generate_pulses("$name/ctr1", high = 240, low = period - 240)
    NIDAQ.CfgImplicitTiming(ct.th, NIDAQ.Val_FiniteSamps , length(volts))
    ao = NIDAQ.analog_output("$name/ao0", range=[minimum(volts),maximum(volts)])
    NIDAQ.CfgSampClkTiming(ao.th, pointer("Ctr1InternalOutput"), 4000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, length(volts))
    NIDAQ.write(ao, volts)
    ai = NIDAQ.analog_input("$name/ai0:2")
    NIDAQ.CfgSampClkTiming(ai.th, pointer("Ctr1InternalOutput"), 4000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, length(volts))
    NIDAQ.start(ai); NIDAQ.start(ao); NIDAQ.start(ct)
    sleep(1.01*period*(2+length(volts))./80e6) # clock is 80MHz
    Vi = NIDAQ.read(ai, Float64, length(volts))
    df = DataFrames.DataFrame(Vo = volts, V1 = Vi[:,1], Vx = Vi[:,2], Vy = Vi[:,3])
    CSV.write(Dates.format(Dates.now(),stamp), df)
    NIDAQ.clear(ai); NIDAQ.clear(ao); NIDAQ.clear(ct)
end

#end
