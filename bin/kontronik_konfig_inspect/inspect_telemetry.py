"""Read-only K-KONFIG 1.3.11 telemetry evidence extractor.
Dependencies: pefile, capstone. The target executable is never launched.
The fixed addresses are valid only for the checked SHA256. Output is analysis
material, not a UART codec, firmware vector or hardware capability approval.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

EXPECTED_SHA256 = "59675dd9b603ad2b86b7435965f5f9f5ac7331ae8eaf7748cf8d33dd53fed5ee"
DEFAULT_EXE = r"C:\Program Files (x86)\Kontronik\KKonfig_V1.3.11.exe"
ANCHORS = {4201710: 'jmp dword ptr [eax*4 + 0x404608]',
 4206478: 'call 0x40cc20',
 4206490: 'call 0x40d2e0',
 4206541: 'cmp byte ptr [0x4124c4], 0',
 4206578: 'mov eax, 0x7c1f',
 4206632: 'or ax, 0x60',
 4206684: 'mov ecx, 0x100',
 4222467: 'mov edi, 0xfa',
 4222486: 'sete byte ptr [0x4124c4]',
 4222528: 'mov esi, 0x226',
 4222549: 'mov byte ptr [0x412455], dl',
 4225714: 'push 0x194',
 4225769: 'push 0x195',
 4231213: 'shr eax, 0xa',
 4231216: 'and eax, 0x1f',
 4231308: 'and eax, 0x1f',
 4231400: 'and eax, 0x3e0',
 4231407: 'cmp eax, 0x60',
 4231412: 'cmp eax, 0x100',
 4247235: 'or cx, 7',
 4247371: 'or cx, 8',
 4247505: 'mov byte ptr [0x41248f], 1',
 4247939: 'mov al, byte ptr [0x41248e]',
 4247944: 'and al, 0x1f',
 4247956: 'mov ecx, 0x3ff',
 4247964: 'mov ecx, 0x400',
 4248830: 'mov byte ptr [0x41248f], 7',
 4248900: 'mov byte ptr [0x41248e], 0',
 4248987: 'or cx, 1',
 4249566: 'and ax, cx',
 4249569: 'or ax, 1',
 4251501: 'mov ecx, 0x412458',
 4252352: 'push ebp',
 4252464: 'mov ebx, dword ptr [0x410080]'}
LITERALS = {4261880: 'Aus',
 4261888: 'Kontronik',
 4261908: 'Graupner',
 4261928: 'Futaba',
 4261944: 'Multiplex',
 4261964: 'Mikado',
 4261980: 'Jeti',
 4261992: 'PowerBox',
 4262012: 'FrSky',
 4261344: 'KOSMIK',
 4261424: 'KOLIBRI',
 4261440: 'KOLIBRIX',
 4261368: 'KOSMIKIND',
 4261336: 'LV',
 4261360: 'HV'}
RANGES = {'middle_selection': (4206500, 4206714),
 'family_detection_and_names': (4222355, 4222876),
 'port_labels_and_enabling': (4225318, 4225988),
 'packed_port_readback': (4231193, 4231520),
 'byte_port_readback': (4231505, 4231694),
 'front_handler': (4246560, 4248296),
 'side_handler': (4248288, 4249887),
 'eeprom_write_entry': (4252352, 4252535)}


def extract(path):
    import pefile
    from capstone import Cs, CS_ARCH_X86, CS_MODE_32
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError("Unexpected SHA256; fixed addresses cannot be reused: " + digest)
    pe = pefile.PE(data=data)
    base = pe.OPTIONAL_HEADER.ImageBase
    if base != 0x400000 or pe.FILE_HEADER.Machine != 0x14c:
        raise ValueError("Expected x86 image at preferred base 0x400000")
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    def read(va, size):
        return pe.get_data(va-base, size)
    checked = []
    for va, expected in ANCHORS.items():
        ins = next(md.disasm(read(va, 16), va, count=1))
        actual = ins.mnemonic + " " + ins.op_str
        if actual != expected:
            raise ValueError(f"Instruction mismatch at {va:08X}: {actual}")
        checked.append(dict(va=f"{va:08X}", bytes=ins.bytes.hex(), instruction=actual))
    for va, expected in LITERALS.items():
        if read(va, 100).decode("utf-16le", errors="replace").split("\0")[0] != expected:
            raise ValueError(f"Literal mismatch at {va:08X}")
    dispatch = {}
    for cid, expected in {0x7FB:0x402F8C, 0x7FC:0x402F98, 0x7FE:0x402FA4}.items():
        actual = struct.unpack("<I", read(0x404608+4*(cid-0x7D0), 4))[0]
        if actual != expected:
            raise ValueError("Control dispatch mismatch")
        dispatch[f"{cid:04X}"] = f"{actual:08X}"
    # Only emulate numeric family flag decisions in Python. No native calls,
    # target code execution or USB access. Reject unsupported instructions.
    fragment = {i.address:i for i in md.disasm(read(0x406DDE, 0x406E74-0x406DDE), 0x406DDE)}
    def flags_for(family):
        regs = {"eax":family, "ecx":family}; memory = {}; equal = False
        partial = {"ax":("eax",0,16), "cx":("ecx",0,16), "dx":("edx",0,16),
                   "si":("esi",0,16), "di":("edi",0,16), "dl":("edx",0,8), "dh":("edx",8,8)}
        def value(op):
            if op == "dword ptr [0x410108]":
                return 0  # Unused GetDlgItem address; never called.
            if op in partial:
                reg, shift, width = partial[op]
                return (regs.get(reg,0)>>shift)&((1<<width)-1)
            if op in ("eax", "ecx", "edx", "esi", "edi"):
                return regs.get(op,0)
            return int(op,0)
        def assign(op,v):
            if op.startswith("byte ptr ["):
                memory[int(op[10:-1],0)] = v
            elif op in partial:
                reg, shift, width = partial[op]; mask = ((1<<width)-1)<<shift
                regs[reg] = (regs.get(reg,0)&~mask)|((v<<shift)&mask)
            else:
                regs[op] = v
        pc = 0x406DDE
        for _ in range(100):
            if pc == 0x406E74:
                return memory
            ins = fragment[pc]; ops = ins.op_str.split(", "); nxt = pc+ins.size
            if ins.mnemonic in ("mov", "movzx"):
                assign(ops[0],value(ops[1]))
            elif ins.mnemonic == "cmp":
                equal = value(ops[0]) == value(ops[1])
            elif ins.mnemonic == "xor":
                assign(ops[0],value(ops[0])^value(ops[1]))
            elif ins.mnemonic == "sete":
                assign(ops[0],int(equal))
            elif ins.mnemonic == "je":
                if equal:
                    nxt = int(ops[0],0)
            elif ins.mnemonic == "jmp":
                nxt = int(ops[0],0)
            elif ins.mnemonic != "push":
                raise ValueError("Unsupported family-fragment instruction: " + ins.mnemonic)
            pc = nxt
        raise ValueError("Family fragment did not terminate")
    family_flags = {}
    expected_flags = {200:(0,0,0,0),225:(1,0,0,0),245:(1,0,0,0),250:(0,1,0,0),
                      500:(0,0,1,0),550:(0,0,1,0),700:(0,0,0,1)}
    for family, expected in expected_flags.items():
        mem = flags_for(family)
        if tuple(mem[a] for a in (0x4124C5,0x4124C4,0x412455,0x412454)) != expected:
            raise ValueError("Family flag mismatch")
        family_flags[str(family)] = {f"{a:08X}":v for a,v in mem.items()}
    names = {}
    for family, expected in {100:0x406ECB,101:0x406ECB,200:0x406EDA,
                             225:0x406EF3,245:0x406EF3,250:0x406EDA}.items():
        index = read(0x407BD8+family-100,1)[0]
        actual = struct.unpack("<I",read(0x407BC8+4*index,4))[0]
        if actual != expected:
            raise ValueError("Family name dispatch mismatch")
        names[str(family)] = f"{actual:08X}"
    imports = {i.address:i.name.decode() if i.name else str(i.ordinal)
               for dll in pe.DIRECTORY_ENTRY_IMPORT for i in dll.imports}
    evidence = {}
    for name, (start,end) in RANGES.items():
        rows = []
        for ins in md.disasm(read(start,end-start),start):
            note = next((n for a,n in imports.items() if hex(a) in ins.op_str), "")
            rows.append(f"{ins.address:08X} {ins.mnemonic} {ins.op_str}" + (" ; "+note if note else ""))
        evidence[name] = rows
    return dict(sha256=digest, executed_target=False, verified_instruction_anchors=checked,
                verified_literals={f"{a:08X}":v for a,v in LITERALS.items()},
                control_dispatch=dispatch, family_flags=family_flags,
                family_name_targets=names, evidence=evidence,
                limitations=["USB EEPROM evidence only; new UART/MSP model mapping remains unqualified."])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, default=Path(DEFAULT_EXE))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = extract(args.exe)
    text = json.dumps(result,indent=2,ensure_ascii=True)+"\n"
    if args.output:
        args.output.write_text(text,encoding="utf-8")
        print("PASS: 34 instruction anchors, 15 literals, 3 control routes, 7 family cases, 6 name dispatches; SHA256 verified")
    else:
        print(text,end="")


if __name__ == "__main__":
    main()
