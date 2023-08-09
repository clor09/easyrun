function Get-ScriptPath {
	if ($env:EasyRunExcludePath) {
		$exculdePattern = @($env:EasyRunExcludePath -split ';')
	}
	$paths = ($env:Path -split ';' | Sort-Object -Unique).Where({
			if (-not $_ -or -not $_.StartsWith($HOME)) {
				return $false
			}
			foreach ($p in $exculdePattern) {
				if ($_ -and $_ -like $p) {
					return $false
				}
			}
			Test-Path $_ -PathType Container
		})
	if ($PWD -notin $paths) {
		$paths += $PWD.Path
	}
	return $paths
}

function Get-ScriptTargets([string]$prefix) {
	$scripts = @{}
	foreach ($path in Get-ScriptPath) {
		foreach ($f in (Get-ChildItem "$path/$prefix*.py", "$path/$prefix*.pl", "$path/$prefix*.js")) {
			$scripts[$f.Name] += @($f.FullName)
		}
	}
	$targets = @()
	foreach ($t in $scripts.Keys) {
		$targets += $scripts[$t].Count -eq 1 ? $t : $scripts[$t]
	}
	return $targets
}

function Get-ScriptFile([string]$target) {
	if ($target -match '\\' -or $target -match '/') {
		return @($target)
	}
	$files = @()
	foreach ($path in Get-ScriptPath) {
		if (Test-Path -Path "$path/$target") {
			$files += "$path/$target"
		}
	}
	return $files
}

function Invoke-PScript {
	param(
		[ArgumentCompleter(
			{
				param (
					$commandName,
					$parameterName,
					$wordToComplete,
					$commandAst,
					$fakeBoundParameters
				)
				Get-ScriptTargets $wordToComplete
			})] $target
	)
	if ($target.Length -le 0) {
		throw "Usage: Invoke-PScript [script]"
	}
	$fs = @(Get-ScriptFile $target)
	if ($fs.Count -gt 1) {
		throw "Multi Scriptfile Found: $fs"
	}
 elseif ($fs.Count -lt 1) {
		throw "No Script File Found: $target"
	}
	if ($fs[0] -like '*.py') {
		$bin = $env:EasyRunPython ?? 'python.exe'
	}
 elseif ($fs -like '*.pl') {
		$bin = $env:EasyRunPerl ?? 'perl.exe'
	}
 elseif ($fs -like '*.js') {
		$bin = $env:EasyRunNode ?? 'node.exe'
	}
 else {
		throw "Dont know how to execute script($target) for extension: $((Get-Item $fs[0]).Extension)"
	}

	& $bin $fs[0] @Args
}
