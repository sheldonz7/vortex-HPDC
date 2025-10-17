import os
import sys
import subprocess
from extract_stat import analyze_cache_performance

opencl_bench_apps = ["conv3", "sgemm", "sgemm2", "sgemm3"]

opencl_bench_apps_ai = ["conv3", "sgemm", "sgemm2", "sgemm3", "kmeans", "sfilter", "saxpy", "nearn"]

opencl_bench_app_ai_broken = ["kmeans", "sfilter", "nearn"]
opencl_bench_apps_hpc = ["stencil", "spmv", "transpose", "vecadd", "dotproduct", "lbm", "bfs", "psum", "psort", "gaussian"]

regression_bench_apps = ["conv3x", "sgemmx", "matmul", "sgemm2x", "vecaddx", "stencil3d"]



vortex_configs = []

# socket size
socket_single_core_config = "-DSOCKET_SIZE=1"
socket_quad_core_config = "-DSOCKET_SIZE=4"

# dcache
dcache_cluster_config = "-DNUM_DCACHES=4 -DNUM_ICACHES=2"
dcache_single_bank_config = "-DDCACHE_NUM_BANKS=1"
dcache_dual_bank_config = "-DDCACHE_NUM_BANKS=2"
dcache_quad_bank_config = "-DDCACHE_NUM_BANKS=4"

l2_single_bank_config = "-DL2_NUM_BANKS=1"
l2_write_back_config = "-DL2_WRITEBACK=1"
l3_single_bank_config = "-DL3_NUM_BANKS=1"
l3_write_back_config = "-DL3_WRITEBACK=1"

# repl
vortex_random_configs = "-DDCACHE_REPL_POLICY=0"
vortex_plru_configs = "-DDCACHE_REPL_POLICY=2"
vortex_cyclic_configs = "-DDCACHE_REPL_POLICY=1"

# only modify this to set the target apps
bench_apps = opencl_bench_apps_ai

vortex_basic_params = "--cores=4 --clusters=1"
vortex_dual_clusters_params = "--cores=2 --clusters=2"
sim_params = "--driver=rtlsim --debug=1 --rebuild=1 --perf=2"

vortex_params = vortex_dual_clusters_params 


other_config = "wbufDirEntries=16, wbufDataEntries=8, rtabEntries=8"

bench = {}

bench_settings_cache_opt = {
    "VX cache": {
        "param": "--vxcache",
        "config": [socket_quad_core_config, dcache_cluster_config, dcache_single_bank_config, vortex_plru_configs]
    },
    "HPDC": {
        "param": "--hpdcache",
        "config": [socket_quad_core_config, dcache_cluster_config, dcache_single_bank_config, vortex_plru_configs]
    }
}

bench_settings_repl = {
    "HPDC PLRU": {
        "param": "--hpdcache",
        "config": [socket_single_core_config, dcache_single_bank_config, vortex_plru_configs]
    },
    "HPDC CYCLIC": {
        "param": "--hpdcache",
        "config": [socket_single_core_config, dcache_single_bank_config, vortex_cyclic_configs]
    },
    "HPDC RANDOM": {
        "param": "--hpdcache",
        "config": [socket_single_core_config, dcache_single_bank_config, vortex_random_configs]
    }
}

bench_settings_3 = {
    "VX cache single bank": {
        "param": "--vxcache",
        "config": [socket_single_core_config, dcache_single_bank_config, vortex_plru_configs]
    },
    "VX cache dual bank": {
        "param": "--vxcache",
        "config": [socket_single_core_config, dcache_dual_bank_config, vortex_plru_configs]
    },
    "VX cache multi bank": {
        "param": "--vxcache",
        "config": [socket_single_core_config, dcache_quad_bank_config, vortex_plru_configs]
    }
}

bench_settings_socket4core = {
    "VX cache": {
        "param": "--vxcache",
        "config": [socket_quad_core_config, dcache_single_bank_config, vortex_plru_configs]
    },
    "HPDC": {
        "param": "--hpdcache",
        "config": [socket_quad_core_config, dcache_single_bank_config, vortex_plru_configs]
    }
}

bench_settings_cache_opt_l2 = {
    "VX cache": {
        "param": "--vxcache --l2cache",
        "config": [socket_single_core_config, dcache_single_bank_config, l2_single_bank_config, vortex_plru_configs]
    },
    "VX cache write-back": {
        "param": "--vxcache --l2cache",
        "config": [socket_single_core_config, dcache_single_bank_config, l2_write_back_config, l2_single_bank_config, vortex_plru_configs]
    },
    "HPDC": {
        "param": "--hpdcache --l2cache --l2hpdc",
        "config": [socket_single_core_config, dcache_single_bank_config, l2_single_bank_config, vortex_plru_configs]
    },
    "HPDC write-back": {
        "param": "--hpdcache --l2cache --l2hpdc",
        "config": [socket_single_core_config, dcache_single_bank_config, l2_write_back_config, l2_single_bank_config, vortex_plru_configs]
    }
}



bench_settings_cache_opt_l3 = {
    "VX cache": {
        "param": "--vxcache --l2cache --l3cache",
        "config": [socket_single_core_config, dcache_single_bank_config, l2_single_bank_config, l3_single_bank_config, vortex_plru_configs]
    },
    "HPDC": {
        "param": "--hpdcache --l2cache --l2hpdc --l3cache --l3hpdc",
        "config": [socket_single_core_config, dcache_single_bank_config, l2_single_bank_config, l3_single_bank_config, vortex_plru_configs]
    }
}


# only modify this to set the target benchmark settings
bench_settings = bench_settings_repl

my_env = os.environ.copy()
#my_env["CONFIG"] = vortex_configs




def plot_ipc(bench_params, bench_results, result_file_name):
    import matplotlib.pyplot as plt

    # apps = list(bench_results.keys())
    # ipc_values = [results['IPC'] for results in bench_results.values() if 'performance' in results]

    # plt.bar(apps, ipc_values)
    # plt.xlabel('Benchmark Applications')
    # plt.ylabel('IPC')
    # plt.title('IPC Comparison of Benchmark Applications')
    # plt.xticks(rotation=45)
    # plt.tight_layout()
    # plt.show()

    # plot IPC for each bench param for each app on the same graph
    apps = list(bench_results.keys())
    params = list(bench_params.keys())
    x = range(len(apps))
    width = 0.35  # the width of the bars
    fig, ax = plt.subplots()
    for i, param in enumerate(params):
        ipc_values = [bench_results[app][param]['IPC'] if param in bench_results[app] and 'IPC' in bench_results[app][param] else 0 for app in apps]
        ax.bar([p + i * width for p in x], ipc_values, width, label=param)
    ax.set_xlabel('Benchmark Applications')
    ax.set_ylabel('IPC')
    ax.set_title('IPC Comparison of Benchmark Applications')
    ax.set_xticks([p + width * (len(params) - 1) / 2 for p in x])
    ax.set_xticklabels(apps)
    ax.legend()
    plt.xticks(rotation=45)
    plt.tight_layout()
    # save the plot
    plt.savefig(f"results/{result_file_name}.png")
    plt.show()


if __name__ == "__main__":
    result_file_name = sys.argv[1]
    full_result_path = f"results/{result_file_name}.txt"

    # obtain this from argv
    result_recover = sys.argv[2].lower() == "true"
    # create .txt file to store results
    if not os.path.exists("results"):
        os.makedirs("results")
    if not os.path.exists(full_result_path) or not result_recover:
        with open(full_result_path, 'w') as f:
            # write the configuration as the header
            #f.write(f"Vortex Configs: {vortex_configs}\n")
            f.write(f"Vortex Params: {vortex_params}\n")
            f.write(f"Sim Params: {sim_params}\n")
            f.write("=" * 50 + "\n")


    

    for app in bench_apps:
        try:
            for param, param_value in bench_settings.items(): 
                if result_recover:
                    found = False
                    # recover results from .txt
                    if os.path.exists(full_result_path):
                        with open(full_result_path, 'r') as f:
                            lines = f.readlines()
                            for line in lines:
                                if f"--- Results for {app} {param}---" in line:
                                    # Found the results for this app and param
                                    results = {}
                                    found = True
                                    for line in lines[lines.index(line) + 1:]:
                                        if line.startswith("---"):
                                            break
                                        metric, value = line.split(": ")
                                        results[metric] = float(value.strip().rstrip("%"))
                                        print(f"Recovered {metric} for {app} {param}: {value.strip()}")
                                    # check if result is empty
                                    if not results:
                                        print(f"The result is empty for {app} {param}, skipping.")
                                        break
                                    if app not in bench:
                                        bench[app] = {}
                                    bench[app][param] = results
                                    break
                    if found:
                        print(f"Recovered results for {app} {param}, skipping simulation.")
                        continue

                # print(["./ci/blackbox.sh", f"--app={app}", param_value] +
                #     vortex_params +
                #     sim_params)
                #continue
                custom_configs = " ".join(param_value['config'])
                subprocess.run(
                    f"CONFIGS=\"{custom_configs}\" ./ci/blackbox.sh --app={app} {param_value['param']} {vortex_params} {sim_params}",
                    shell=True,
                    check=True
                )

                with open(f"run.log", 'r') as f:
                    log_data = f.read()
                results = analyze_cache_performance(log_data)

                if app not in bench:
                    bench[app] = {}
                bench[app][param] = results

                # Print the results for each benchmark application
                print(f"--- Results for {app} {param}---")
                for metric, value in results.items():
                    print(f"{metric}: {value:.2f}%")
                print("-" * 30)
                # Append results to the results file
                with open(full_result_path, 'a') as f:
                    f.write(f"--- Results for {app} {param}---\n")
                    for metric, value in results.items():
                        if metric == "IPC" or metric.endswith("mshr_stalls") or metric.endswith("bank_stalls"):
                            f.write(f"{metric}: {value:.2f}\n")
                        else:  
                            f.write(f"{metric}: {value:.2f}%\n")
                    f.write("-" * 30 + "\n")
        except Exception as e:
            print(f"Error occurred while processing {app} {param}: {e}")
            print("Skipping...")

    plot_ipc(bench_settings, bench, result_file_name)