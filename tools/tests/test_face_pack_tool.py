# SPDX-License-Identifier: GPL-3.0-only
"""头像包工具 tools/mod/face_pack.py 与模板 templates/face_pack/: 帧清单自洽、校验能挑出各类错误、打包清单的包内路径正确。
(真正打 .pck 要 Godot, 不在这里测; 引擎认包见 game/tests/test_face_style.gd)"""
import importlib.util
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
import _boot  # noqa: E402,F401
import paths  # noqa: E402

_spec = importlib.util.spec_from_file_location("face_pack", os.path.join(TOOLS, "mod", "face_pack.py"))
FP = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(FP)

TEMPLATE = os.path.join(paths.REPO, "templates", "face_pack")
FRAMES = {"FACE01": {"t0": [8, 6], "t1": [4, 6]}, "Face05": {"t0": [8, 6]}}


def webp(path, size):
    from PIL import Image
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.new("RGBA", size, (255, 0, 0, 128)).save(path, "WEBP")


class Frames(unittest.TestCase):
    def test_template_frames_are_well_formed(self):
        d = FP.load_frames(os.path.join(TEMPLATE, "frames.json"))
        self.assertGreater(len(d), 40)
        for name, fr in d.items():
            self.assertTrue(fr, name)
            for stem, (w, h) in fr.items():
                self.assertRegex(stem, r"^t\d+$", name)
                self.assertGreater(w, 0)
                self.assertGreater(h, 0)
                self.assertEqual((w % 4, h % 4), (0, 0), "头像是 4 倍图: %s/%s" % (name, stem))

    def test_template_has_readme_and_info(self):
        self.assertTrue(os.path.isfile(os.path.join(TEMPLATE, "README.md")))
        with open(os.path.join(TEMPLATE, "info.json"), encoding="utf-8") as f:
            self.assertTrue(json.load(f)["name"].strip())


class CheckPack(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def p(self, rel):
        return os.path.join(self.dir, *rel.split("/"))

    def test_good_pack_is_partial_and_ok(self):
        webp(self.p("Face/FACE01/t0.webp"), (8, 6))
        errors, warnings, files = FP.check_pack(self.dir, FRAMES)
        self.assertEqual(errors, [])
        self.assertEqual([r for _, r in files], ["Face/FACE01/t0.webp"])
        self.assertTrue(any("1 / 3" in w for w in warnings), warnings)

    def test_each_kind_of_mistake_is_reported(self):
        webp(self.p("Face/FACE01/t0.webp"), (9, 6))      # 尺寸错
        webp(self.p("Face/FACE01/t9.webp"), (4, 6))      # 没有这一帧
        webp(self.p("Face/face05/t0.webp"), (8, 6))      # 目录大小写
        os.makedirs(self.p("Face/Face05"))
        with open(self.p("Face/Face05/t0.png"), "wb") as f:   # 不是 webp
            f.write(b"x")
        errors, _, files = FP.check_pack(self.dir, FRAMES)
        text = "\n".join(errors)
        self.assertIn("尺寸 9x6, 应为 8x6", text)
        self.assertIn("没有这一帧", text)
        self.assertIn("是不是想写 Face05", text)
        self.assertIn("只认 .webp", text)
        self.assertEqual(files, [])

    def test_missing_face_dir_and_empty_pack(self):
        self.assertTrue(FP.check_pack(self.dir, FRAMES)[0])
        os.makedirs(self.p("Face"))
        self.assertIn("一张头像都没有", "\n".join(FP.check_pack(self.dir, FRAMES)[0]))

    def test_broken_image_is_an_error(self):
        os.makedirs(self.p("Face/FACE01"))
        with open(self.p("Face/FACE01/t0.webp"), "wb") as f:
            f.write(b"not an image")
        self.assertIn("打不开", "\n".join(FP.check_pack(self.dir, FRAMES)[0]))

    def test_pack_id_rules(self):
        self.assertEqual(FP.check_id("face_mine2"), [])
        for bad in ("Face-Mine", "我的", "classic", "auto", "hk", ""):
            self.assertTrue(FP.check_id(bad), bad)

    def test_pack_items_use_the_pack_id_prefix(self):
        webp(self.p("Face/FACE01/t0.webp"), (8, 6))
        with open(self.p("info.json"), "w", encoding="utf-8") as f:
            f.write('{"name": "x"}')
        files = FP.check_pack(self.dir, FRAMES)[2]
        items = FP.pack_items("face_mine", self.dir, files)
        self.assertEqual(sorted(r for _, r in items), ["res://mod/face_mine/Face/FACE01/t0.webp", "res://mod/face_mine/info.json"])
        self.assertEqual(FP.check_info(self.dir), [])

    def test_info_warnings(self):
        self.assertTrue(FP.check_info(self.dir))   # 没有 info.json
        with open(self.p("info.json"), "w", encoding="utf-8") as f:
            f.write("{")
        self.assertIn("合法 JSON", FP.check_info(self.dir)[0])


if __name__ == "__main__":
    unittest.main()
