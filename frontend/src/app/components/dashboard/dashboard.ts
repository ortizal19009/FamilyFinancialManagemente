import { Component, HostListener, OnDestroy, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { NavigationEnd, Router, RouterModule } from '@angular/router';
import { filter, Subscription } from 'rxjs';
import { ApiService, ReportExportParams } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent implements OnInit, OnDestroy {
  private apiService = inject(ApiService);
  private authService = inject(AuthService);
  private router = inject(Router);
  private subscriptions = new Subscription();

  currentUser = this.authService.currentUser;
  readonly reportTypeOptions = [
    { value: 'summary', label: 'Resumen general' },
    { value: 'movements', label: 'Movimientos' },
    { value: 'accounts', label: 'Cuentas y productos' },
    { value: 'expenses', label: 'Gastos' },
    { value: 'planning', label: 'Planificación' }
  ] as const;
  readonly reportFormatOptions = [
    { value: 'pdf', label: 'PDF' },
    { value: 'xml', label: 'XML' }
  ] as const;

  reportForm: ReportExportParams = {
    type: 'summary',
    format: 'pdf',
    date_from: this.buildIsoDate(new Date(new Date().getFullYear(), new Date().getMonth(), 1)),
    date_to: this.buildIsoDate(new Date()),
    month: new Date().getMonth() + 1,
    year: new Date().getFullYear()
  };
  isExportingReport = false;
  reportFeedback = '';
  stats = {
    availableBalance: 0,
    totalDebt: 0,
    monthlyExpenses: 0,
    totalAssets: 0,
    investmentsCurrentValue: 0,
    investmentsInvestedAmount: 0
  };

  recentExpenses: any[] = [];

  ngOnInit() {
    this.loadDashboardSummary();
    this.subscriptions.add(
      this.router.events
        .pipe(filter((event) => event instanceof NavigationEnd))
        .subscribe((event) => {
          const navigation = event as NavigationEnd;
          if (navigation.urlAfterRedirects.startsWith('/dashboard')) {
            this.loadDashboardSummary();
          }
        })
    );
  }

  ngOnDestroy() {
    this.subscriptions.unsubscribe();
  }

  @HostListener('window:focus')
  onWindowFocus() {
    this.loadDashboardSummary();
  }

  @HostListener('document:visibilitychange')
  onVisibilityChange() {
    if (document.visibilityState === 'visible') {
      this.loadDashboardSummary();
    }
  }

  loadDashboardSummary() {
    this.apiService.getDashboardSummary().subscribe(summary => {
      this.stats = summary.stats;
      this.recentExpenses = summary.recentExpenses;
    });
  }

  requiresDateRange(): boolean {
    return this.reportForm.type === 'movements' || this.reportForm.type === 'expenses';
  }

  requiresMonthYear(): boolean {
    return this.reportForm.type === 'planning';
  }

  exportReport() {
    this.isExportingReport = true;
    this.reportFeedback = '';

    const payload: ReportExportParams = {
      type: this.reportForm.type,
      format: this.reportForm.format
    };

    if (this.requiresDateRange()) {
      payload.date_from = this.reportForm.date_from;
      payload.date_to = this.reportForm.date_to;
    }

    if (this.requiresMonthYear()) {
      payload.month = this.reportForm.month;
      payload.year = this.reportForm.year;
    }

    this.apiService.exportReport(payload).subscribe({
      next: (blob) => {
        const extension = this.reportForm.format;
        const fileName = `reporte_${this.reportForm.type}_${new Date().toISOString().slice(0, 10)}.${extension}`;
        const url = window.URL.createObjectURL(blob);
        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.download = fileName;
        anchor.click();
        window.URL.revokeObjectURL(url);
        this.reportFeedback = `Reporte ${this.reportForm.format.toUpperCase()} generado correctamente`;
        this.isExportingReport = false;
      },
      error: (error) => {
        this.reportFeedback = error?.error?.msg || 'No se pudo generar el reporte';
        this.isExportingReport = false;
      }
    });
  }

  private buildIsoDate(value: Date): string {
    const year = value.getFullYear();
    const month = `${value.getMonth() + 1}`.padStart(2, '0');
    const day = `${value.getDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
