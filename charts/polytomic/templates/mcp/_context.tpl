{{/*
MCP wrappers each build their context the same way:

  {{- $values := deepCopy .Values.mcp -}}
  {{- $ctx := dict "root" . "values" $values "name" "mcp" -}}
  {{- include "polytomic.decorateMcpValues" (dict "ctx" $ctx "target" $values) -}}

deepCopy keeps the decoration out of .Values.mcp, so each template starts
from the same undecorated block.
*/}}
