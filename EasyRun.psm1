function Get-ScriptPath {
    if($env:EasyRunExcludePath) {
        $exculdePattern = @($env:EasyRunExcludePath -split ';')
    } else {
        $exculdePattern = @(
            '',
            'C:\WINDOWS*'
        )
    }
    if ($exculdePattern -notcontains '') {
        $exculdePattern += ''
    }
	$paths = ($env:Path -split ';').Where({
			foreach ($p in $exculdePattern) {
				if ($_ -like $p) {
					return $false
				}
			}
			return $true
		})
	if ((Get-Location) -notin $paths) {
		$paths += (Get-Location).Path
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
			})] $script
	)
	$fs = @(Get-ScriptFile $script)
	if ($fs.Count -gt 1) {
		Write-Error "Multi Scriptfile Found: $fs"
		return
	} elseif ($fs.Count -lt 1) {
		Write-Error "No Script File Found: $script"
		return
	}
	if ($fs[0] -like '*.py') {
		$bin = $env:EasyRunPython ?? 'python.exe'
	} elseif ($fs -like '*.pl') {
		$bin = $env:EasyRunPerl ?? 'perl.exe'
	} elseif ($fs -like '*.js') {
		$bin = $env:EasyRunNode ?? 'node.exe'
	} else {
		Write-Error "Dont know how to execute script($script) for extension: $((Get-Item $fs[0]).Extension)"
		return
	}

	& $bin $fs[0] @Args
}
