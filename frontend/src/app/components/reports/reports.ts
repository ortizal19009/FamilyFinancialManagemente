import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';

import { ApiService, ReportFormat, ReportType } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';

interface ReportOption {
  value: ReportType;
  label: string;
  description: string;
  group: string;
}

const REPORT_OPTIONS: ReportOption[] = [
  { value: 'summary', label: 'Resumen general', description: 'Indicadores, conteos y gastos recientes', group: 'Resumen' },
  { value: 'net-worth', label: 'Patrimonio neto', description: 'Activos, deudas y patrimonio neto', group: 'Resumen' },
  { value: 'expenses', label: 'Gastos', description: 'Detalle de gastos y totales por categoría', group: 'Movimientos' },
  { value: 'expenses-category', label: 'Gastos por categoría', description: 'Concentrado por categoría con porcentajes', group: 'Movimientos' },
  { value: 'movements', label: 'Movimientos', description: 'Ingresos y egresos combinados', group: 'Movimientos' },
  { value: 'planning', label: 'Presupuesto', description: 'Ejecución contra el plan del mes', group: 'Movimientos' },
  { value: 'accounts', label: 'Cuentas y productos', description: 'Bancos, cuentas, tarjetas y préstamos', group: 'Cuentas' },
  { value: 'cards', label: 'Tarjetas', description: 'Saldo, límites y pagos', group: 'Cuentas' },
  { value: 'loans', label: 'Préstamos', description: 'Cuotas, saldo restante y amortización', group: 'Cuentas' },
  { value: 'investments', label: 'Inversiones', description: 'Valor actual y rentabilidad', group: 'Deudas y bienes' },
  { value: 'assets', label: 'Activos', description: 'Inventario de bienes', group: 'Deudas y bienes' },
  { value: 'debts', label: 'Deudas', description: 'Deudores, micro deudas, tarjetas y préstamos', group: 'Deudas y bienes' },
  { value: 'audit', label: 'Auditoría', description: 'Registro de actividad (solo admin)', group: 'Administración' },
];

const FORMATS: { value: ReportFormat; label: string }[] = [
  { value: 'pdf', label: 'PDF' },
  { value: 'xlsx', label: 'Excel (XLSX)' },
  { value: 'csv', label: 'CSV' },
  { value: 'xml', label: 'XML' },
];

@Component({
  selector: 'app-reports',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './reports.html',
  styleUrl: './reports.scss'
})
export class ReportsComponent {
  private apiService = inject(ApiService);
  private authService = inject(AuthService);

  reportOptions = REPORT_OPTIONS;
  formats = FORMATS;
  currentUser = this.authService.currentUser;

  selectedType: ReportType = 'summary';
  selectedFormat: ReportFormat = 'pdf';
  dateFrom = '';
  dateTo = '';
  month: number | null = new Date().getMonth() + 1;
  year: number | null = new Date().getFullYear();

  exporting = false;
  successMsg = '';
  errorMsg = '';

  get groups(): string[] {
    const groups: string[] = [];
    for (const option of this.reportOptions) {
      if (!groups.includes(option.group)) {
        groups.push(option.group);
      }
    }
    return groups;
  }

  optionsFor(group: string): ReportOption[] {
    return this.reportOptions.filter(option => option.group === group);
  }

  selectReport(type: ReportType) {
    this.selectedType = type;
    this.clearMessages();
  }

  clearMessages() {
    this.successMsg = '';
    this.errorMsg = '';
  }

  canExportAudit(): boolean {
    return !(this.selectedType === 'audit' && !this.authService.isAdmin());
  }

  exportReport() {
    if (!this.canExportAudit()) {
      this.errorMsg = 'El reporte de auditoría requiere rol de administrador';
      setTimeout(() => this.errorMsg = '', 4000);
      return;
    }

    this.clearMessages();
    this.exporting = true;
    this.apiService.exportReport({
      type: this.selectedType,
      format: this.selectedFormat,
      date_from: this.dateFrom || undefined,
      date_to: this.dateTo || undefined,
      month: this.month ?? undefined,
      year: this.year ?? undefined,
    }).subscribe({
      next: (blob) => {
        const timestamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '');
        this.downloadBlob(blob, `reporte_${this.selectedType}_${timestamp}.${this.selectedFormat}`);
        this.exporting = false;
        this.successMsg = 'Reporte generado correctamente';
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.exporting = false;
        this.errorMsg = error?.error?.msg || 'No se pudo generar el reporte';
        setTimeout(() => this.errorMsg = '', 4000);
      }
    });
  }

  private downloadBlob(blob: Blob, filename: string) {
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 60000);
  }
}