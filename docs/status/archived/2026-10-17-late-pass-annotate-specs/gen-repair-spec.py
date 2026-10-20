D = "/tmp/dhp-specs/"
open(D + "repair-spec.tsv", "w").close()


def gen(file_path, verdicts_path, pairs, out):
    with open(verdicts_path) as vf:
        verdicts = vf.read().splitlines()
    lines = []
    for idx, lineno in pairs:
        v = verdicts[idx - 1]
        if v.startswith("routed - "):
            kind, val = "r", v[9:]
        elif v.startswith("current - "):
            kind, val = "r", v[10:]
        elif v.startswith("done"):
            kind, val = "v", v
        elif v.startswith("partial - "):
            kind, val = "r", v[10:]
        else:
            raise SystemExit(f"unclassifiable verdict idx {idx}: {v[:60]}")
        val = val.replace("\t", " ").strip()
        lines.append(f"{file_path}\t{lineno}\t{kind}\t{val}")
    with open(out, "a") as f:
        f.write("\n".join(lines) + "\n")


F612 = "docs/status/2026-10-17_06-12_issue-4-bootstrap-fix-and-p3-close-status.md"
pairs = [(1, 32), (2, 33), (3, 34), (4, 35)]
fkeys = list(range(76, 102)) + list(range(103, 116))
for p, ln in enumerate(fkeys):
    pairs.append((5 + p, ln))
gen(F612, D + "verdicts-0612.txt", pairs, D + "repair-spec.tsv")
# f27 line 102: the morning-pass verdict, restored from git blob 660ef08
with open(D + "repair-spec.tsv", "a") as f:
    f.write(
        F612
        + "\t102\tv\tdone 2026-10-17 - on their lock d7e1334 (0.16.26): stalwart.service went ACTIVE and provision FINISHED at boot - the bootstrap fix is validated on the issue version, deadlock class gone; the remaining red is the file's OWN deliberate deadlock-pin (machine.fail on a manual re-start) whose comment prescribes flip-to-success + TLS/webadmin/admin leg re-adds (new pbx-artmann work item, TODO row added this pass)\n"
    )

gen(
    "docs/status/2026-10-17_05-37_readme-agents-superb-pass-self-review.md",
    D + "verdicts-0537.txt",
    [(i, 146 + i) for i in range(9, 23)],
    D + "repair-spec.tsv",
)
gen(
    "docs/status/2026-10-17_06-05_agents-md-drift-fix-prune-self-review.md",
    D + "verdicts-0605.txt",
    [(i, 159 + i) for i in range(9, 23)],
    D + "repair-spec.tsv",
)
with open(D + "repair-spec.tsv") as sf:
    print("specs written:", sum(1 for _ in sf))
