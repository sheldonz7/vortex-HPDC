import re
import collections
import sys

def analyze_cache_performance(log_content):
    """
    Parses a log file to calculate average cache miss rates.

    Args:
        log_content: A string containing the log file data.

    Returns:
        A dictionary with the calculated miss rates.
    """
    # This dictionary will store the totals for reads, writes, and their misses.
    # defaultdict is used to avoid checking if a key exists before adding to it.
    stats = collections.defaultdict(lambda: collections.defaultdict(int))

    # Regex to capture the cache name (dcache, l2cache, etc.) and the relevant stats.
    # It looks for lines containing reads, writes, read misses, or write misses.
    # The `(?:core\d+: )?` part makes the "coreX: " section optional,
    # so it can also match shared caches like l3cache.
    pattern = re.compile(
        r"PERF: (?:core\d+: )?(\w+cache)\s+(reads|writes|read misses|write misses|bank stalls|mshr stalls)=(\d+)"
    )

    perf_pattern = re.compile(
        r"PERF: instrs=(\d+),\s*cycles=(\d+),\s*IPC=([\d.]+)"
    )

    # Find all matches in the provided log content
    for match in pattern.finditer(log_content):
        print("match: ", match)
        cache_name, metric, value = match.groups()
        print("name: " + cache_name + " metric: " + metric + " value: " + value)
        stats[cache_name][metric] += int(value)

    # Extract overall performance metrics (optional, for additional context)
    perf_match = perf_pattern.search(log_content)
    if perf_match:
        print("match: ", perf_match)
        instrs, cycles, ipc = perf_match.groups()
        print(f"Total Instructions: {instrs}")
        print(f"Total Cycles: {cycles}")
        print(f"Overall IPC: {ipc}")
        stats['performance']['instrs'] = int(instrs)
        stats['performance']['cycles'] = int(cycles)
        stats['performance']['IPC'] = float(ipc)


    # --- Calculate Miss Rates ---
    results = {}

    # Calculate for dcache (separating read and write)
    if 'dcache' in stats:
        dcache_stats = stats['dcache']
        total_reads = dcache_stats['reads']
        read_misses = dcache_stats['read misses']
        total_writes = dcache_stats['writes']
        write_misses = dcache_stats['write misses']
        bank_stalls = dcache_stats['bank stalls']
        mshr_stalls = dcache_stats['mshr stalls']
        
        print("read misses: , ", read_misses)
        print("total reads: , ", total_reads)
        print("write misses: , ", write_misses)
        print("total writes: , ", total_writes)
        print("bank stalls: , ", bank_stalls)
        print("mshr stalls: , ", mshr_stalls)

        read_miss_rate = (read_misses / total_reads) * 100 if total_reads > 0 else 0
        write_miss_rate = (write_misses / total_writes) * 100 if total_writes > 0 else 0
        
        results['dcache_read_miss_rate'] = read_miss_rate
        results['dcache_write_miss_rate'] = write_miss_rate
        results['dcache_total_bank_stalls'] = bank_stalls
        results['dcache_total_mshr_stalls'] = mshr_stalls

    # Calculate for other caches (l2cache, l3cache, etc.)
    if 'l2cache' in stats:
        l2cache_stats = stats['l2cache']
        total_reads = l2cache_stats['reads']
        read_misses = l2cache_stats['read misses']
        total_writes = l2cache_stats['writes']
        write_misses = l2cache_stats['write misses']
        bank_stalls = l2cache_stats['bank stalls']
        mshr_stalls = l2cache_stats['mshr stalls']

        print("read misses: , ", read_misses)
        print("total reads: , ", total_reads)
        print("write misses: , ", write_misses)
        print("total writes: , ", total_writes)
        print("bank stalls: , ", bank_stalls)
        print("mshr stalls: , ", mshr_stalls)
        read_miss_rate = (read_misses / total_reads) * 100 if total_reads > 0 else 0
        write_miss_rate = (write_misses / total_writes) * 100 if total_writes > 0 else 0
        
        results['l2cache_read_miss_rate'] = read_miss_rate
        results['l2cache_write_miss_rate'] = write_miss_rate
        results['l2cache_total_bank_stalls'] = bank_stalls
        results['l2cache_total_mshr_stalls'] = mshr_stalls

    if 'l3cache' in stats:
        l3cache_stats = stats['l3cache']
        total_reads = l3cache_stats['reads']
        read_misses = l3cache_stats['read misses']
        total_writes = l3cache_stats['writes']
        write_misses = l3cache_stats['write misses']
        bank_stalls = l3cache_stats['bank stalls']
        mshr_stalls = l3cache_stats['mshr stalls']

        print("read misses: , ", read_misses)
        print("total reads: , ", total_reads)
        print("write misses: , ", write_misses)
        print("total writes: , ", total_writes)
        print("bank stalls: , ", bank_stalls)
        print("mshr stalls: , ", mshr_stalls)

        read_miss_rate = (read_misses / total_reads) * 100 if total_reads > 0 else 0
        write_miss_rate = (write_misses / total_writes) * 100 if total_writes > 0 else 0
        
        results['l3cache_read_miss_rate'] = read_miss_rate
        results['l3cache_write_miss_rate'] = write_miss_rate
        results['l3cache_total_bank_stalls'] =  bank_stalls
        results['l3cache_total_mshr_stalls'] = mshr_stalls
    
    if 'performance' in stats:
        results['instrs'] = stats['performance']['instrs']
        results['cycles'] = stats['performance']['cycles']
        results['IPC'] = stats['performance']['IPC']

    return results

# --- Example Usage ---

# 1. Create a dummy log file content for demonstration.
#    Replace this with your actual file reading logic.
dummy_log_data = """
# Some irrelevant lines in the log
INFO: Simulation starting...

PERF: core0: dcache reads=10000
PERF: core0: dcache writes=5000
PERF: core0: dcache read misses=500 (hit ratio=95%)
PERF: core0: dcache write misses=2000 (hit ratio=60%)

PERF: core1: dcache reads=12000
PERF: core1: dcache writes=4000
PERF: core1: dcache read misses=1200 (hit ratio=90%)
PERF: core1: dcache write misses=1000 (hit ratio=75%)

# Shared L2 Cache Stats
PERF: l2cache reads=1700
PERF: l2cache writes=3000
PERF: l2cache read misses=80
PERF: l2cache write misses=150

# Shared L3 Cache Stats
PERF: l3cache reads=230
PERF: l3cache writes=0
PERF: l3cache read misses=23
PERF: l3cache write misses=0

INFO: Simulation finished.
"""

# 2. To read from a file named 'simulation.log', you would use:
# with open('simulation.log', 'r') as f:
#     log_data = f.read()
# results = analyze_cache_performance(log_data)


if __name__ == "__main__":

    # read in data from .log file, file path provided as argument
    log_file_path = sys.argv[1]

    with open(log_file_path, 'r') as f:
        log_data = f.read()
    results = analyze_cache_performance(log_data)

    # 3. Print the results in a formatted way
    print("--- Average Cache Miss Rate Analysis ---")
    if 'dcache_read_miss_rate' in results:
        print(f"D-Cache Average Read Miss Rate:  {results['dcache_read_miss_rate']:.2f}%")
        print(f"D-Cache Average Write Miss Rate: {results['dcache_write_miss_rate']:.2f}%")
        print("-" * 38)

    if 'l2cache_read_miss_rate' in results:
        print(f"l2Cache Average Read Miss Rate:  {results['l2cache_read_miss_rate']:.2f}%")
        print(f"l2Cache Average Write Miss Rate: {results['l2cache_write_miss_rate']:.2f}%")
        print("-" * 38)

    if 'l3cache_read_miss_rate' in results:
        print(f"l3Cache Average Read Miss Rate:  {results['l3cache_read_miss_rate']:.2f}%")
        print(f"l3Cache Average Write Miss Rate: {results['l3cache_write_miss_rate']:.2f}%")
        print("-" * 38)

    if 'performance' in results:
        print(f"Total Instructions: {results['performance']['instrs']}")
        print(f"Total Cycles: {results['performance']['cycles']}")
        print(f"Overall IPC: {results['performance']['IPC']:.2f}")
        print("-" * 38)

    #return results