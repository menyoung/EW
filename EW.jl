#module EW

import NIDAQ, CSV, DataFrames, Dates, PyCall

export init, arb

const dev = "Dev1"

function init(volt)
    println("Disconnect (toggle off add) voltage and press Enter")
    readline()
    NIDAQ.ResetDevice(codeunits(dev))
    ao0 = NIDAQ.analog_output("$dev/ao0")
    NIDAQ.start(ao0)
    NIDAQ.write(ao0,[volt])
    NIDAQ.clear(ao0)
    println("Output 0 = $volt V. Connect (toggle on add) voltage.")
end

stamp = Dates.DateFormat("yymmdd_HHMMSS")

function arb(period, volts)
    wt = 1.01*period*(2+length(volts))./80e6 # clock is 80MHz
    println("$(period/80) us = $(80e6 / period) Hz will take $wt seconds for $(length(volts)) points. I-V gain (1e5)?")
    gI = try parse(Float64, readline()) catch; 1e5 end
    println("What is Lock-in analog gain (1e2)? [offset sould be zero!]")
    gV = try parse(Float64, readline()) catch; 1e2 end
    println("$dev/ctr1 Set up video camera trigger then give this experiment a name (Enter to abort)")
    name = readline()
    if isempty(name) | all(isspace, name) return end
    fn = Dates.format(Dates.now(),stamp) * "_$name.csv"
    ct = NIDAQ.generate_pulses("$dev/ctr1", high = 240, low = period - 240)
    NIDAQ.CfgImplicitTiming(ct.th, NIDAQ.Val_FiniteSamps , length(volts))
    ao = NIDAQ.analog_output("$dev/ao0", range=[minimum(volts),maximum(volts)])
    NIDAQ.CfgSampClkTiming(ao.th, pointer("Ctr1InternalOutput"), 4000, NIDAQ.Val_Falling, NIDAQ.Val_FiniteSamps, length(volts))
    NIDAQ.write(ao, volts)
    ai = NIDAQ.analog_input("$dev/ai0:3")
    NIDAQ.CfgSampClkTiming(ai.th, pointer("Ctr1InternalOutput"), 4000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, length(volts))
    NIDAQ.start(ai); NIDAQ.start(ao); NIDAQ.start(ct)
    sleep(wt)
    Vi = NIDAQ.read(ai, Float64, length(volts))
    df = DataFrames.DataFrame(V = volts, I = Vi[:,1] ./ gI, V1 = Vi[:,1], Vx = Vi[:,2] ./ gV, Vy = Vi[:,3] ./ gV, V4 = Vi[:,4])

    CSV.write(fn, df)
    NIDAQ.clear(ai); NIDAQ.clear(ao); NIDAQ.clear(ct)
    fn
end

sweeps(Va, Vc, step, n=1) = [0:-step:Va+step;repeat([Va:step:Vc-step;Vc:-step:Va+step],n);Va:step:0]

# repeat(volts, inner=n) repeats each number n times then go to next

# python code using NetworkX to create a random Euler circuit
py"""
import networkx as nx
import random

def simplegraph_eulerian_circuit(G, source):
    if G.is_directed():
        degree = G.out_degree
        edges = G.out_edges
    else:
        degree = G.degree
        edges = G.edges
    vertex_stack = [source]
    last_vertex = None
    while vertex_stack:
        current_vertex = vertex_stack[-1]
        if degree(current_vertex) == 0:
            if last_vertex is not None:
                yield (last_vertex, current_vertex)
            last_vertex = current_vertex
            vertex_stack.pop()
        else:
            _, next_vertex = random.sample(list(edges(current_vertex)),1)[0]
            vertex_stack.append(next_vertex)
            G.remove_edge(current_vertex, next_vertex)

def euler_random(n):
    g = nx.complete_graph(n, nx.DiGraph())
    return [u for u, v in simplegraph_eulerian_circuit(g, next(iter(g)))]
"""
# Julia interface adds the return to 0 vertex
euler_random(n) = [py"euler_random"(n);0]

function euler_volts(Va, Vc, step)
    vlist = [0;step:step:Vc;-step:-step:Va]
    map(x -> vlist[x+1], euler_random(length(vlist)))
end

#end
