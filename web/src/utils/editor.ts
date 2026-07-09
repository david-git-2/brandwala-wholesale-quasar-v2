export const cleanEditorHtml = (html: string) => {
  const clean = html.replace(/<[^>]*>/g, '').trim();
  return clean.length > 0 ? html.trim() : null;
};

export const buildTableElement = (rows: number, cols: number) => {
  const table = document.createElement('table');
  table.className = 'rich-text-table';
  table.setAttribute('border', '1');
  table.setAttribute('cellpadding', '8');
  table.setAttribute('cellspacing', '0');

  const thead = document.createElement('thead');
  const headerRow = document.createElement('tr');
  for (let c = 0; c < cols; c++) {
    const th = document.createElement('th');
    th.textContent = `Header ${c + 1}`;
    headerRow.appendChild(th);
  }
  thead.appendChild(headerRow);
  table.appendChild(thead);

  const tbody = document.createElement('tbody');
  for (let r = 0; r < rows; r++) {
    const tr = document.createElement('tr');
    for (let c = 0; c < cols; c++) {
      const td = document.createElement('td');
      td.innerHTML = '&nbsp;';
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }
  table.appendChild(tbody);

  return table;
};

type QEditorRef = {
  focus?: () => void;
  caret?: { save?: () => void; restore?: () => void };
  $el?: HTMLElement;
};

export const insertTableAtCaret = (editorRef: QEditorRef | null | undefined, rows: number, cols: number) => {
  const editor = editorRef;
  if (!editor || rows <= 0 || cols <= 0) return;

  const contentEl = editor.$el?.querySelector('.q-editor__content') as HTMLElement | null;
  if (!contentEl) return;

  editor.focus?.();
  editor.caret?.restore?.();

  const table = buildTableElement(rows, cols);
  const sel = window.getSelection();
  let inserted = false;

  if (sel && sel.rangeCount > 0) {
    const range = sel.getRangeAt(0);
    if (contentEl.contains(range.commonAncestorContainer)) {
      range.deleteContents();
      range.insertNode(table);

      const paragraph = document.createElement('p');
      paragraph.appendChild(document.createElement('br'));
      table.after(paragraph);

      range.setStart(paragraph, 0);
      range.collapse(true);
      sel.removeAllRanges();
      sel.addRange(range);
      inserted = true;
    }
  }

  if (!inserted) {
    contentEl.appendChild(table);
    const paragraph = document.createElement('p');
    paragraph.appendChild(document.createElement('br'));
    contentEl.appendChild(paragraph);
  }

  contentEl.dispatchEvent(new Event('input', { bubbles: true }));
  editor.caret?.save?.();
};
