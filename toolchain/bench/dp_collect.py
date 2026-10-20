import os, re
def collect_dp():
    man = os.path.join(os.path.dirname(__file__), "dp_budget.toml")
    resv, owner = [], None
    if os.path.exists(man):
        for ln in open(man):
            mo = re.search(r'owner\s*=\s*"([^"]+)"', ln)
            mr = re.search(r'range\s*=\s*\[\s*(0x[0-9a-fA-F]+)\s*,\s*(0x[0-9a-fA-F]+)', ln)
            if mo: owner = mo.group(1)
            if mr and owner and owner.startswith("fcc_"):
                resv.append({"owner":owner,"lo":int(mr.group(1),16),"hi":int(mr.group(2),16)})
    # fcc DP usage = 0 today; Tier 2/3 computes this from the user binary's DP refs.
    # Overlap check is within the user page only (reservations above).
    overlaps=[]
    for i in range(len(resv)):
        for j in range(i+1,len(resv)):
            a,b=resv[i],resv[j]
            if a["lo"]<=b["hi"] and b["lo"]<=a["hi"]: overlaps.append([a["owner"],b["owner"]])
    return {"fcc_bytes":0,"reservations":resv,"overlaps":overlaps}
