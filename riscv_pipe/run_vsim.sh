import subprocess
import shutil

# File paths
riscv_sv = "riscv_pipeline.sv"
backup_sv = "riscv_pipeline_backup.sv"
tests_file = "tests.txt"
output_log = "sim_output.txt"

# Backup the original .sv file
shutil.copyfile(riscv_sv, backup_sv)

# Read test filenames from tests.txt
with open(tests_file, 'r') as tf:
    tests = [line.strip() for line in tf if line.strip()]

# Clear the output log file
with open(output_log, 'w') as f:
    pass

# Dictionary to track test outcomes
summary = {}

# Process each test
for testfile in tests:
    print(f"🔁 Running test with: {testfile}")

    # Replace 'template.memfile' with current test filename
    with open(backup_sv, 'r') as original, open(riscv_sv, 'w') as modified:
        for line in original:
            modified.write(line.replace("template.memfile", testfile))

    # Run the simulation and capture the output
    try:
        result = subprocess.run(
            ["vsim", "-do", "riscv_pipeline.do", "-c"],
            capture_output=True,
            text=True,
            check=False
        )
        output = result.stdout + result.stderr
    except Exception as e:
        output = f"❌ Error running vsim for {testfile}: {e}\n"

    # Determine test result
    if "Simulation succeeded" in output:
        status = "✅ SUCCESS"
    elif "Simulation failed" in output:
        status = "❌ FAILURE"
    else:
        status = "⚠️  UNKNOWN"

    summary[testfile] = status

    # Append output to sim_output.txt
    with open(output_log, 'a') as log:
        log.write(f"===== Running Test: {testfile} =====\n")
        log.write(output)
        log.write(f"===== End Test: {testfile} =====\n\n")

# Restore the original file
shutil.move(backup_sv, riscv_sv)

# Print summary
print("\n📋 Simulation Summary:")
for test, result in summary.items():
    print(f"  {test}: {result}")

print(f"\n✅ All simulations complete. Full logs in {output_log}")

