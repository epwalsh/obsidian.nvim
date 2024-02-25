local Path = require "obsidian.path"
local util = require "obsidian.util"

describe("Path.new()", function()
  it("should initialize with both method syntax and regular dot access", function()
    ---@type obsidian.Path
    local path

    path = Path.new "README.md"
    assert.equal("README.md", path.filename)

    path = Path:new "README.md"
    assert.equal("README.md", path.filename)
  end)

  it("should return same object when arg is already a path", function()
    local path = Path.new "README.md"
    assert.equal(path, Path.new(path))
  end)

  it("should init from a plenary path", function()
    local PlenaryPath = require "plenary.path"
    local path = Path.new "README.md"
    assert.is_true(path == Path.new(PlenaryPath:new "README.md"))
  end)
end)

describe("Path.is_path_obj()", function()
  it("should return true for obsidian.Path objects", function()
    local path = Path.new "README.md"
    assert.is_true(Path.is_path_obj(path))
  end)

  it("should return false for all other kinds of objects", function()
    assert.is_false(Path.is_path_obj(1))
    assert.is_false(Path.is_path_obj { a = 2 })
    assert.is_false(Path.is_path_obj(nil))
  end)
end)

describe("Path.__eq", function()
  it("should compare with other paths correctly", function()
    assert.is_true(Path:new "README.md" == Path:new "README.md")
    assert.is_true(Path:new "/foo" == Path:new "/foo/")

    local path = Path:new "README.md"
    local _ = path.name
    assert.is_true(path == Path:new "README.md")
    assert.is_true(path == Path.new(path))
  end)
end)

describe("Path.__div", function()
  it("should join paths", function()
    assert(Path:new "/foo/" / "bar" == Path:new "/foo/bar")
  end)
end)

describe("Path.name", function()
  it("should return final component", function()
    assert.equals("bar.md", Path:new("/foo/bar.md").name)
  end)
end)

describe("Path.suffix", function()
  it("should return final suffix", function()
    assert.equals(".md", Path:new("/foo/bar.md").suffix)
    assert.equals(".gz", Path:new("/foo/bar.tar.gz").suffix)
  end)

  it("should return nil when there is no suffix", function()
    assert.equals(nil, Path:new("/foo/bar").suffix)
  end)
end)

describe("Path.suffix", function()
  it("should return all extensions", function()
    assert.are_same({ ".md" }, Path:new("/foo/bar.md").suffixes)
    assert.are_same({ ".tar", ".gz" }, Path:new("/foo/bar.tar.gz").suffixes)
  end)

  it("should return empty list when there is no suffix", function()
    assert.are_same({}, Path:new("/foo/bar").suffixes)
  end)
end)

describe("Path.stem", function()
  it("should return the final name without suffix", function()
    assert.equals("bar", Path:new("/foo/bar.md").stem)
    assert.equals(nil, Path:new("/").stem)
  end)
end)

describe("Path.with_suffix()", function()
  it("should create a new path with the new suffix", function()
    assert.is_true(Path:new("/foo/bar.md"):with_suffix ".tar.gz" == Path.new "/foo/bar.tar.gz")
    assert.is_true(Path:new("/foo/bar.tar.gz"):with_suffix ".bz2" == Path.new "/foo/bar.tar.bz2")
    assert.is_true(Path:new("/foo/bar"):with_suffix ".md" == Path.new "/foo/bar.md")
  end)
end)

describe("Path.is_absolute()", function()
  it("should work for windows or unix paths", function()
    assert(Path:new("/foo/"):is_absolute())
    if util.get_os() == util.OSType.Windows then
      assert(Path:new("C:/foo/"):is_absolute())
      assert(Path:new("C:\\foo\\"):is_absolute())
    end
  end)
end)

describe("Path.joinpath()", function()
  it("can join multiple", function()
    assert.is_true(Path.new "foo/bar/baz.md" == Path.new("foo"):joinpath("bar", "baz.md"))
    assert.is_true(Path.new "foo/bar/baz.md" == Path.new("foo/"):joinpath("bar/", "baz.md"))
    assert.is_true(Path.new "foo/bar/baz.md" == Path.new("foo/"):joinpath("bar/", "/baz.md"))
  end)
end)

describe("Path.relative_to()", function()
  it("should resolve the relative path", function()
    assert.equals("baz.md", Path:new("/foo/bar/baz.md"):relative_to("/foo/bar/").filename)
    assert.equals("baz.md", Path:new("/baz.md"):relative_to("/").filename)
  end)

  it("should raise an error when the relative path can't be resolved", function()
    assert.has_error(function()
      Path:new("/bar/bar/baz.md"):relative_to "/foo/"
    end)
  end)
end)

describe("Path.parent()", function()
  it("should get the parent of the current", function()
    assert.are_same(Path.new("/foo/bar/README.md"):parent(), Path.new "/foo/bar")
  end)
end)

describe("Path.parents()", function()
  it("should collect all logical parents", function()
    assert.are_same(Path.new("/foo/bar/README.md"):parents(), { Path.new "/foo/bar", Path.new "/foo", Path.new "/" })
  end)
end)

describe("Path.resolve()", function()
  it("should always resolve to the absolute path when it exists", function()
    assert.equals(vim.fs.normalize(assert(vim.loop.fs_realpath "README.md")), Path.new("README.md"):resolve().filename)
  end)

  it("should always resolve to the an absolute path if a parent exists", function()
    assert.equals(
      vim.fs.normalize(assert(vim.loop.fs_realpath ".")) .. "/tmp/dne.md",
      Path.new("tmp/dne.md"):resolve().filename
    )
    assert.equals(
      vim.fs.normalize(assert(vim.loop.fs_realpath ".")) .. "/dne.md",
      Path.new("dne.md"):resolve().filename
    )
  end)
end)

describe("Path.exists()", function()
  it("should return true when the path exists", function()
    assert.is_true(Path.new("README.md"):exists())
    assert.is_true(Path.new("lua"):exists())
  end)

  it("should return false when the path does not exists", function()
    assert.is_false(Path.new("dne.md"):exists())
  end)
end)

describe("Path.is_file()", function()
  it("should return true when the path is a file", function()
    assert.is_true(Path.new("README.md"):is_file())
    assert.is_false(Path.new("README.md"):is_dir())
  end)

  it("should return false when the path is a directory", function()
    assert.is_false(Path.new("lua"):is_file())
  end)
end)

describe("Path.is_dir()", function()
  it("should return true when the path is a directory", function()
    assert.is_true(Path.new("lua"):is_dir())
    assert.is_false(Path.new("lua"):is_file())
  end)

  it("should return false when the path is a file", function()
    assert.is_false(Path.new("README.md"):is_dir())
  end)

  it("should return false when the path does not exist", function()
    assert.is_false(Path.new("dne.md"):is_dir())
  end)
end)

describe("Path.mkdir()", function()
  it("should make a directory", function()
    local dir = Path.temp()
    assert.is_false(dir:exists())

    dir:mkdir()
    assert.is_true(dir:exists())
    assert.is_true(dir:is_dir())
    assert.is_false(dir:is_file())

    dir:mkdir { exist_ok = true }
    assert.is_true(dir:exists())

    assert.error(function()
      dir:mkdir { exist_ok = false }
    end)

    dir:rmdir()
    assert.is_false(dir:exists())
  end)

  it("should make a directory and its parents", function()
    local base_dir = Path.temp()
    local dir = base_dir / "foo"
    assert.is_false(base_dir:exists())
    assert.is_false(dir:exists())

    dir:mkdir { parents = true }
    assert.is_true(base_dir:exists())
    assert.is_true(dir:exists())

    dir:rmdir()
    assert.is_false(dir:exists())

    base_dir:rmdir()
    assert.is_false(base_dir:exists())
  end)

  it("should rename a file", function()
    local temp_file = Path.temp()
    temp_file:touch()
    assert.is_true(temp_file:is_file())

    local target = Path.temp()
    assert.is_false(target:exists())

    temp_file:rename(target)
    assert.is_true(target:is_file())
    assert.is_false(temp_file:is_file())

    target:unlink()
    assert.is_false(target:is_file())
  end)

  it("should rename a directory", function()
    local temp_dir = Path.temp()
    temp_dir:mkdir()
    assert.is_true(temp_dir:is_dir())

    local target = Path.temp()
    assert.is_false(target:exists())

    temp_dir:rename(target)
    assert.is_true(target:is_dir())
    assert.is_false(temp_dir:is_dir())

    target:rmdir()
    assert.is_false(target:exists())
  end)
end)
