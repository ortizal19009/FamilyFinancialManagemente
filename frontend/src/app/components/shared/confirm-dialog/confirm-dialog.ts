import { Component, input, output } from '@angular/core';

export interface ConfirmOptions {
  title?: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
}

@Component({
  selector: 'app-confirm-dialog',
  standalone: true,
  templateUrl: './confirm-dialog.html',
  styleUrl: './confirm-dialog.scss'
})
export class ConfirmDialogComponent {
  options = input<ConfirmOptions>({ message: '¿Estás seguro?' });
  confirmed = output<boolean>();

  onConfirm() {
    this.confirmed.emit(true);
  }

  onCancel() {
    this.confirmed.emit(false);
  }
}