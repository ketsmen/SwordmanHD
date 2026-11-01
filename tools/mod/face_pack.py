#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""头像包工具: 校验自己做的头像, 打成能放进游戏 mod/ 文件夹的 .pck。模板与说明见 templates/face_pack/README.md。

  python3 tools/mod/face_pack.py check <包目录>                  校验 (只看, 不写任何文件)
  python3 tools/mod/face_pack.py pack  <包目录> [--id 包名] [--out 文件或目录]   校验通过后打包, 缺省输出 ./<包名>.pck
  python3 tools/mod/face_pack.py frames --hd4x <hd4x 目录> [--out frames.json]  (维护者) 从高清头像目录重新生成帧清单

<包目录> 里要有 Face/<头像目录>/tN.webp (名字、大小写、像素尺寸都要与 frames.json 一致), 可选 info.json {"name": "设定里显示的名字"}。
包名 (= 设定「头像风格」里这个包的 id, 也是包内 res://mod/<包名>/) 缺省取目录名: 只用小写字母、数字、下划线, 不能是 classic / auto / hk。
只放了一部分头像也能用: 缺的那几张游戏里自动退回经典头像。pack 需要 Godot 4.7.2 (tools/paths.py 的 godot_exe, 或环境变量 TDJ_GODOT)。
退出码: 0 通过; 1 校验失败或打包失败; 2 用法错误。
"""
import argparse
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # tools/
import _boot  # noqa: F401,E402
import paths  # noqa: E402

REPO = paths.REPO
DEFAULT_FRAMES = os.path.join(REPO, "templates", "face_pack", "frames.json")
RESERVED = {"classic", "auto", "hk"}   # 与 game/engine/render/face_packs.gd 的 reserved 一致
ID_RE = re.compile(r"^[a-z0-9_]+$")


def load_frames(path=DEFAULT_FRAMES):
    """帧清单 {头像目录: {帧名: [宽, 高]}}"""
    with open(path, encoding="utf-8") as f:
        return json.load(f)["dirs"]


def check_id(pack_id):
    """包名问题列表 (空 = 合法)"""
    if not ID_RE.match(pack_id):
        return ["包名 %r 不合法: 只能用小写字母、数字、下划线 (用 --id 指定, 或改目录名)" % pack_id]
    if pack_id in RESERVED:
        return ["包名 %r 是保留的风格值, 换一个 (用 --id 指定)" % pack_id]
    return []


def check_pack(pack_dir, frames):
    """校验包目录。返回 (errors, warnings, files): files = [(源文件, 包内相对路径 如 Face/FACE01/t0.webp)] (只含通过检查的头像)。"""
    try:
        from PIL import Image
    except ImportError:
        sys.exit("需要 Pillow: pip install Pillow (见 tools/requirements-build.txt)")
    errors, warnings, files = [], [], []
    face = os.path.join(pack_dir, "Face")
    if not os.path.isdir(face):
        return ["没有 Face/ 目录: %s (头像放在 Face/<头像目录>/tN.webp)" % pack_dir], warnings, files
    lower = {d.lower(): d for d in frames}
    seen = 0
    for d in sorted(os.listdir(face)):
        dp = os.path.join(face, d)
        if not os.path.isdir(dp):
            warnings.append("Face/ 下有多余的文件, 已忽略: " + d)
            continue
        if d not in frames:
            hint = " (是不是想写 %s? 目录名区分大小写)" % lower[d.lower()] if d.lower() in lower else ""
            errors.append("Face/%s: 不是头像目录%s" % (d, hint))
            continue
        for fn in sorted(os.listdir(dp)):
            rel = "Face/%s/%s" % (d, fn)
            stem, ext = os.path.splitext(fn)
            if ext != ".webp":
                if ext.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                    errors.append("%s: 只认 .webp (游戏读 tN.webp, 其它格式会被忽略)" % rel)
                else:
                    warnings.append("%s: 多余的文件, 已忽略" % rel)
                continue
            if stem not in frames[d]:
                errors.append("%s: 经典头像没有这一帧 (%s 只有 %s)" % (rel, d, ", ".join(sorted(frames[d], key=lambda s: int(s[1:])))))
                continue
            try:
                with Image.open(os.path.join(dp, fn)) as im:
                    size = list(im.size)
            except Exception as e:  # PIL 对坏图抛各种异常
                errors.append("%s: 打不开 (%s)" % (rel, e))
                continue
            if size != frames[d][stem]:
                errors.append("%s: 尺寸 %dx%d, 应为 %dx%d (头像要与经典头像同尺寸, 否则对位和大小都会变)" % (rel, size[0], size[1], frames[d][stem][0], frames[d][stem][1]))
                continue
            files.append((os.path.join(dp, fn), rel))
            seen += 1
    total = sum(len(v) for v in frames.values())
    if not errors and seen == 0:
        errors.append("Face/ 里一张头像都没有")
    if seen:
        warnings.append("覆盖 %d / %d 帧, 其余游戏里用经典头像" % (seen, total))
    return errors, warnings, files


def pack_pck(godot, out, items):
    """用 tools/release/pack_pck.gd 把 items [(源文件, res:// 路径)] 打成 out。成功返回 None, 失败返回说明。"""
    lst = out + ".list"
    with open(lst, "w", encoding="utf-8", newline="\n") as f:
        for src, res in items:
            f.write("%s\t%s\n" % (os.path.abspath(src).replace("\\", "/"), res))
    tmp = out + ".tmp"   # 先写临时文件, 成功再替换: 失败不留半个包
    try:
        r = subprocess.run([godot, "--headless", "--path", os.path.join(REPO, "game").replace("\\", "/"), "--script",
                            os.path.join(REPO, "tools", "release", "pack_pck.gd").replace("\\", "/"), "--", "--list=" + lst, "--out=" + tmp],
                           capture_output=True, text=True, encoding="utf-8", errors="replace", env=paths.env_for_godot())
    finally:
        os.remove(lst)
    if r.returncode or not os.path.isfile(tmp):
        if os.path.isfile(tmp):
            os.remove(tmp)
        return r.stdout + r.stderr
    os.replace(tmp, out)
    return None


def pack_items(pack_id, pack_dir, files):
    """包内清单: 头像 + info.json (有就带)"""
    items = [(src, "res://mod/%s/%s" % (pack_id, rel)) for src, rel in files]
    info = os.path.join(pack_dir, "info.json")
    if os.path.isfile(info):
        items.append((info, "res://mod/%s/info.json" % pack_id))
    return items


def check_info(pack_dir):
    """info.json 的问题 (只是警告)"""
    p = os.path.join(pack_dir, "info.json")
    if not os.path.isfile(p):
        return ["没有 info.json: 设定里这个包会显示包名, 想显示好听的名字就加 {\"name\": \"...\"}"]
    try:
        with open(p, encoding="utf-8") as f:
            j = json.load(f)
    except ValueError as e:
        return ["info.json 不是合法 JSON: %s" % e]
    if not isinstance(j, dict) or not str(j.get("name", "")).strip():
        return ["info.json 里没有 name, 设定里会显示包名"]
    return []


def cmd_check(a):
    pack_dir = os.path.abspath(a.pack_dir)
    pack_id = a.id or os.path.basename(pack_dir.rstrip("/\\"))
    errors, warnings, files = check_pack(pack_dir, load_frames(a.frames))
    errors = check_id(pack_id) + errors
    warnings += check_info(pack_dir)
    for w in warnings:
        print("提示: " + w)
    for e in errors:
        print("错误: " + e)
    print("%s: %s (包名 %s, %d 张头像)" % (pack_dir, "通过" if not errors else "未通过, %d 个错误" % len(errors), pack_id, len(files)))
    return files, errors, pack_id, pack_dir


def cmd_pack(a):
    files, errors, pack_id, pack_dir = cmd_check(a)
    if errors:
        return 1
    godot = paths.godot_exe()
    if not os.path.isfile(godot):
        print(paths.missing_godot_hint())
        return 1
    out = a.out or "."
    if os.path.isdir(out) or not out.endswith(".pck"):
        os.makedirs(out, exist_ok=True)
        out = os.path.join(out, pack_id + ".pck")
    err = pack_pck(godot, out, pack_items(pack_id, pack_dir, files))
    if err is not None:
        print("打包失败:\n" + err)
        return 1
    print("已生成 %s (%.1f MB): 放进游戏的 mod/ 文件夹, 打开设定里的「头像风格」选它" % (out, os.path.getsize(out) / 1048576))
    return 0


def cmd_frames(a):
    from PIL import Image
    root = os.path.join(a.hd4x, "Face")
    if not os.path.isdir(root):
        print("没有 %s" % root)
        return 1
    dirs = {}
    for d in sorted(os.listdir(root)):
        dp = os.path.join(root, d)
        if not os.path.isdir(dp):
            continue
        frames = {}
        for fn in sorted(os.listdir(dp), key=lambda s: (len(s), s)):
            stem, ext = os.path.splitext(fn)
            if ext == ".webp":
                with Image.open(os.path.join(dp, fn)) as im:
                    frames[stem] = list(im.size)
        if frames:
            dirs[d] = frames
    doc = {"format": 1, "note": "头像包的帧清单: 头像目录 -> 帧名 -> [宽, 高] 像素 (与经典头像同尺寸; 目录名、帧名区分大小写)。由 tools/mod/face_pack.py frames 生成, 别手改。", "dirs": dirs}
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("{\n \"format\": 1,\n \"note\": %s,\n \"dirs\": {\n" % json.dumps(doc["note"], ensure_ascii=False))
        f.write(",\n".join("  %s: %s" % (json.dumps(d), json.dumps(v, separators=(",", ":"))) for d, v in dirs.items()))
        f.write("\n }\n}\n")
    print("%s: %d 个头像目录, %d 帧" % (a.out, len(dirs), sum(len(v) for v in dirs.values())))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="头像包校验与打包 (说明见 templates/face_pack/README.md)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("check", "pack"):
        p = sub.add_parser(name)
        p.add_argument("pack_dir", help="包目录 (里面有 Face/)")
        p.add_argument("--id", help="包名 (缺省取目录名)")
        p.add_argument("--frames", default=DEFAULT_FRAMES, help="帧清单 (缺省 templates/face_pack/frames.json)")
        if name == "pack":
            p.add_argument("--out", help="输出文件 (.pck) 或目录, 缺省当前目录下 <包名>.pck")
    p = sub.add_parser("frames")
    p.add_argument("--hd4x", required=True, help="高清资源目录 (里面有 Face/)")
    p.add_argument("--out", default=DEFAULT_FRAMES)
    a = ap.parse_args(argv)
    if a.cmd == "check":
        return 1 if cmd_check(a)[1] else 0
    return cmd_pack(a) if a.cmd == "pack" else cmd_frames(a)


if __name__ == "__main__":
    sys.exit(main())
